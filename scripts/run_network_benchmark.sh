#!/bin/bash

set -e

# Network Performance Analysis: Measures TCP throughput and bandwidth utilization across virtual network stacks using iperf
# Evaluates network virtualization overhead including NAT translation, virtual bridge latency, and guest OS network driver efficiency
ENVIRONMENT=$1
TIMESTAMP=${2:-$(date +%Y%m%d_%H%M%S)}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: baremetal, container, vm"
    exit 1
fi

# Network benchmark parameters (per assignment requirements)
TEST_DURATION=30            # 30 seconds as per assignment
SERVER_PORT=5001
SERVER_WINDOW="1M"          # 1MB server TCP window
CLIENT_BUFFER="8192K"       # 8192KB client write buffer as per assignment
THREADS=(1 2 4 8 16 32 64)  # Full thread array as per assignment

echo "Starting $ENVIRONMENT network benchmark..."

# Setup networking for container environment
setup_container_networking() {
    if [ "$ENVIRONMENT" = "container" ]; then
        echo "Verifying container networking and iperf availability..."
        # Test container connectivity to host
        if ! sudo docker exec cs553-container ping -c 1 172.17.0.1 >/dev/null 2>&1; then
            echo "Warning: Container cannot reach host at 172.17.0.1"
            echo "Container network info:"
            sudo docker exec cs553-container ip route
        fi
    elif [ "$ENVIRONMENT" = "vm" ]; then
        echo "Verifying VM networking..."
        # Test VM connectivity to host
        HOST_IP=$(sudo lxc exec cs553-vm -- ip route | grep default | awk '{print $3}' | head -1)
        if ! sudo lxc exec cs553-vm -- ping -c 1 $HOST_IP >/dev/null 2>&1; then
            echo "Warning: VM cannot reach host at $HOST_IP"
            echo "VM network info:"
            sudo lxc exec cs553-vm -- ip route
        fi
    fi
}

# Start iperf server with assignment specifications  
start_server() {
    if [ "$ENVIRONMENT" = "baremetal" ]; then
        echo "[DEBUG] Starting server on all interfaces: iperf -s -p $SERVER_PORT -w $SERVER_WINDOW (backgrounded)"
        iperf -s -p $SERVER_PORT -w $SERVER_WINDOW &
        sleep 3
        echo "[DEBUG] Checking if server is listening on port $SERVER_PORT..."
        ss -ln | grep :$SERVER_PORT || echo "[DEBUG] Server not found in listening ports"
    elif [ "$ENVIRONMENT" = "container" ]; then
        # Install iperf in container for client use
        sudo docker exec cs553-container bash -c 'command -v iperf >/dev/null || (apt-get update -qq && apt-get install -y iperf)'
        # Start iperf server on HOST (so container can connect to it)
        echo "[DEBUG] Starting iperf server on HOST for container benchmark"
        iperf -s -p $SERVER_PORT -w $SERVER_WINDOW &
        sleep 3
        echo "[DEBUG] Checking if server is listening on port $SERVER_PORT..."
        ss -ln | grep :$SERVER_PORT || echo "[DEBUG] Server not found in listening ports"
    elif [ "$ENVIRONMENT" = "vm" ]; then
        # Install iperf in VM for client use
        sudo lxc exec cs553-vm -- bash -c 'command -v iperf >/dev/null || (apt-get update -qq && apt-get install -y iperf)'
        # Start iperf server on HOST (so VM can connect to it)
        echo "[DEBUG] Starting iperf server on HOST for VM benchmark"
        iperf -s -p $SERVER_PORT -w $SERVER_WINDOW &
        sleep 3
        echo "[DEBUG] Checking if server is listening on port $SERVER_PORT..."
        ss -ln | grep :$SERVER_PORT || echo "[DEBUG] Server not found in listening ports"
    fi
}

# Stop iperf server
stop_server() {
    if [ "$ENVIRONMENT" = "baremetal" ]; then
        pkill iperf 2>/dev/null || true
    elif [ "$ENVIRONMENT" = "container" ]; then
        sudo docker exec cs553-container pkill iperf 2>/dev/null || true
    elif [ "$ENVIRONMENT" = "vm" ]; then
        sudo lxc exec cs553-vm -- pkill iperf 2>/dev/null || true
    fi
}

# Run network test with assignment specifications
run_test() {
    local threads=$1
    local output_file=$2
    
    echo "Testing $threads threads (duration: ${TEST_DURATION}s)..."
    
    if [ "$ENVIRONMENT" = "baremetal" ]; then
        # Get the primary network interface IP (not loopback) for realistic network testing
        NETWORK_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || echo "127.0.0.1")
        if [ "$NETWORK_IP" = "127.0.0.1" ]; then
            # Fallback: try to get first non-loopback IP
            NETWORK_IP=$(ip addr | grep -E 'inet [0-9]+\.' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1 || echo "127.0.0.1")
        fi
        echo "[DEBUG] Using network IP: $NETWORK_IP (avoiding loopback for realistic network performance)"
        echo "[DEBUG] Running client: iperf -c $NETWORK_IP -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e"
        if ! iperf -c $NETWORK_IP -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e > "$output_file" 2>&1; then
            echo "[ERROR] iperf client failed for $threads threads"
            echo "Error output:" && cat "$output_file"
            echo "Debug info: Tried to connect to $NETWORK_IP instead of loopback"
        else
            echo "[DEBUG] Test completed for $threads threads"
        fi
    elif [ "$ENVIRONMENT" = "container" ]; then
        # Container client connects to host (tests container networking performance)
        echo "[DEBUG] Running container client: iperf -c 172.17.0.1 -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e"
        if ! sudo docker exec cs553-container iperf -c 172.17.0.1 -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e > "$output_file" 2>&1; then
            echo "[ERROR] Container iperf client failed for $threads threads"
            echo "Error output:" && cat "$output_file"
            echo "Debug info:"
            echo "- Checking container connectivity..."
            sudo docker exec cs553-container ping -c 2 172.17.0.1 || echo "Container cannot ping host"
            echo "- Checking if iperf server is running on host..."
            ss -ln | grep :$SERVER_PORT || echo "No server listening on port $SERVER_PORT"
            echo "- Container iperf version:"
            sudo docker exec cs553-container iperf --version || echo "iperf not found in container"
        else
            echo "[DEBUG] Container test completed for $threads threads"
        fi
    elif [ "$ENVIRONMENT" = "vm" ]; then
        # VM client connects to host (tests VM networking performance) 
        # Get host IP from VM perspective (gateway)
        HOST_IP=$(sudo lxc exec cs553-vm -- ip route | grep default | awk '{print $3}' | head -1)
        echo "[DEBUG] Running VM client: iperf -c $HOST_IP -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e"
        if ! sudo lxc exec cs553-vm -- iperf -c $HOST_IP -p $SERVER_PORT -P $threads -t $TEST_DURATION -l $CLIENT_BUFFER --nodelay --trip-times -e > "$output_file" 2>&1; then
            echo "[ERROR] VM iperf client failed for $threads threads"
            echo "Error output:" && cat "$output_file"
            echo "Debug info:"
            echo "- VM trying to connect to host at: $HOST_IP"
            echo "- Checking VM connectivity..."
            sudo lxc exec cs553-vm -- ping -c 2 $HOST_IP || echo "VM cannot ping host"
            echo "- Checking if iperf server is running on host..."
            ss -ln | grep :$SERVER_PORT || echo "No server listening on port $SERVER_PORT"
            echo "- VM iperf version:"
            sudo lxc exec cs553-vm -- iperf --version || echo "iperf not found in VM"
        else
            echo "[DEBUG] VM test completed for $threads threads"
        fi
    fi
}

# Parse results (iperf3 JSON format)
parse_results() {
    local file=$1
    local threads=$2
    
    if [ ! -f "$file" ]; then
        echo "Error: results file not found"
        return
    fi
    
    # Parse iperf (version 2) output format
    # Example: "[SUM] 0.0000-5.0082 sec  36.9 GBytes  63.4 Gbits/sec"
    # Example: "[  1] 0.0000-5.0109 sec  25.1 GBytes  43.1 Gbits/sec"
    
    # Debug parsing (uncomment if needed)
    # echo "[DEBUG] Parsing file: $file"
    # cat "$file" | grep -E "\[(SUM|.*)\].*Gbits/sec|\[(SUM|.*)\].*Mbits/sec" || echo "[DEBUG] No bandwidth lines found"
    
    # Try to get SUM line first (for multiple threads)
    local throughput=$(grep "\[SUM\]" "$file" | tail -1 | awk '{
        for(i=1; i<=NF; i++) {
            if($i ~ /Tbits\/sec/) {
                print $(i-1)*1000
                exit
            } else if($i ~ /Gbits\/sec/) {
                print $(i-1)
                exit
            } else if($i ~ /Mbits\/sec/) {
                print $(i-1)/1000
                exit
            }
        }
    }' 2>/dev/null)
    
    # If no SUM line (single thread), parse individual thread line
    if [ -z "$throughput" ] || [ "$throughput" = "" ]; then
        throughput=$(grep -E "\[[[:space:]]*[0-9]+\].*Tbits/sec|\[[[:space:]]*[0-9]+\].*Gbits/sec|\[[[:space:]]*[0-9]+\].*Mbits/sec" "$file" | tail -1 | awk '{
            for(i=1; i<=NF; i++) {
                if($i ~ /Tbits\/sec/) {
                    print $(i-1)*1000
                    exit
                } else if($i ~ /Gbits\/sec/) {
                    print $(i-1)
                    exit
                } else if($i ~ /Mbits\/sec/) {
                    print $(i-1)/1000
                    exit
                }
            }
        }' 2>/dev/null)
    fi
    
    # Default to N/A if parsing failed
    if [ -z "$throughput" ] || [ "$throughput" = "" ]; then
        throughput="N/A"
    fi
    
    # Parse latency from iperf enhanced output
    # Primary: Try to get average burst latency from enhanced output (-e flag)
    # Example: "2.083/1.184/26.013/0.879 ms (2405/8388608)"
    local latency=$(grep "ms.*(" "$file" | grep -v "Interval" | head -1 | awk '{
        for(i=1; i<=NF; i++) {
            if($i ~ /^[0-9]+\.[0-9]+\//) {
                split($i, parts, "/")
                print parts[1]  # Return average latency
                exit
            }
        }
    }' 2>/dev/null)
    
    # Fallback: Parse initial RTT from connection line if enhanced parsing fails
    if [ -z "$latency" ] || [ "$latency" = "" ]; then
        latency=$(grep "connected with.*irtt=" "$file" | head -1 | sed -n 's/.*irtt=[0-9]*\/[0-9]*\/\([0-9]*\).*/\1/p' | awk '{print $1/1000}' 2>/dev/null)
    fi
    
    # Final fallback
    if [ -z "$latency" ] || [ "$latency" = "" ]; then
        latency="N/A"
    fi
    
    # Server count (always 1 for this assignment)
    local server=1
    
    # Write to CSV
    echo "$ENVIRONMENT,$server,$threads,$latency,$throughput," >> "$SUMMARY_FILE"
    
    echo "  Result: $throughput Gbits/sec, Latency: $latency ms"
}

# Main execution
mkdir -p results/${ENVIRONMENT}/network

SUMMARY_FILE="results/${ENVIRONMENT}/network/network_summary_${TIMESTAMP}.csv"
echo "Virtualization Type,Server,Client Threads,Latency (ms),Measured Throughput (Gbits/s),Efficiency" > "$SUMMARY_FILE"

# Setup
setup_container_networking

# Cleanup any existing servers
stop_server

# Start server
start_server

# Run tests
for thread_count in "${THREADS[@]}"; do
    output_file="results/${ENVIRONMENT}/network/network_${ENVIRONMENT}_${thread_count}threads_${TIMESTAMP}.txt"
    
    run_test "$thread_count" "$output_file"
    parse_results "$output_file" "$thread_count"
done

# Cleanup
stop_server

echo "Network benchmark completed!"
echo "Results saved to: $SUMMARY_FILE"
