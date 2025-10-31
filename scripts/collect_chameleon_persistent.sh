#!/bin/bash

# Distributed Cloud Benchmark Orchestration: Manages fault-tolerant benchmark execution across Chameleon Cloud instances using persistent tmux sessions
# Provides automated deployment, monitoring, and result collection for multi-environment performance analysis with network resilience

set -e

# Configuration
CHAMELEON_USER="cc"
CHAMELEON_KEY="~/.ssh/id_ed25519"
LOCAL_RESULTS_DIR="results_chameleon"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_NAME="hw2_benchmarks_$TIMESTAMP"

usage() {
    echo "Usage: $0 <command> <instance_type> <instance_ip>"
    echo "Commands:"
    echo "  start   - Start benchmarks in persistent session"
    echo "  check   - Check progress of running benchmarks"
    echo "  watch   - Watch benchmark progress in real-time"
    echo "  attach  - Attach to the running tmux session"
    echo "  collect - Collect results from completed benchmarks"
    echo ""
    echo "Instance types: baremetal, container, vm"
    echo ""
    echo "Examples:"
    echo "  $0 start container 129.114.108.206   # Start benchmarks"
    echo "  $0 check container 129.114.108.206   # Quick status check"
    echo "  $0 watch container 129.114.108.206   # Real-time log viewing"
    echo "  $0 attach container 129.114.108.206  # Attach to tmux session"
    echo "  $0 collect container 129.114.108.206 # Collect results"
}

# Start persistent benchmark session
start_benchmarks() {
    local instance_type=$1
    local instance_ip=$2
    
    echo "=== Persistent Chameleon Benchmark Collection ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "Session: $SESSION_NAME"
    echo "Setting up persistent benchmark session..."
    
    # Create directories and upload all scripts to ensure we have latest versions
    ssh -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip" "mkdir -p ~/hw2/scripts"
    scp -i "$CHAMELEON_KEY" scripts/*.sh "$CHAMELEON_USER@$instance_ip:~/hw2/scripts/"
    
    # Create benchmark script on remote host
    ssh -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip" << EOF
cd ~/hw2

# Install tmux if not present
sudo apt-get update -qq
sudo apt-get install -y tmux bc python3

# Verify environment setup based on instance type
if [ "$instance_type" = "baremetal" ]; then
    echo "=== Setting up Baremetal Environment ===" | tee -a benchmark.log
    # Install required packages for baremetal
    sudo apt-get install -y sysbench iperf
elif [ "$instance_type" = "container" ]; then
    echo "=== Setting up Container Environment ===" | tee -a benchmark.log
    # Ensure container is running
    if ! sudo docker ps | grep -q cs553-container; then
        echo "Starting cs553-container..." | tee -a benchmark.log
        sudo docker run -d --privileged --name cs553-container ubuntu:22.04 sleep infinity || true
        sudo docker exec cs553-container apt-get update -qq
        sudo docker exec cs553-container apt-get install -y sysbench iperf
    fi
elif [ "$instance_type" = "vm" ]; then
    echo "=== VM Environment - Skipping all setup, going straight to benchmarks ===" | tee -a benchmark.log
fi

# Create benchmark script with proper variable substitution
cat > run_benchmarks.sh << SCRIPT_EOF
#!/bin/bash
cd ~/hw2
echo "=== Starting $instance_type Benchmarks at \$(date) ===" | tee benchmark.log

echo "=== CPU Benchmark ===" | tee -a benchmark.log
timeout 1800 bash scripts/run_cpu_benchmark.sh $instance_type $TIMESTAMP 2>&1 | tee -a benchmark.log

echo "=== Memory Benchmark ===" | tee -a benchmark.log  
timeout 1800 bash scripts/run_memory_benchmark.sh $instance_type $TIMESTAMP 2>&1 | tee -a benchmark.log

echo "=== Network Benchmark ===" | tee -a benchmark.log
timeout 1800 bash scripts/run_network_benchmark.sh $instance_type $TIMESTAMP 2>&1 | tee -a benchmark.log

echo "=== Disk Benchmark (LAST) ===" | tee -a benchmark.log
timeout 3600 bash scripts/run_disk_benchmark.sh $instance_type $TIMESTAMP 2>&1 | tee -a benchmark.log

echo "=== All Benchmarks Complete ===" | tee -a benchmark.log
date | tee -a benchmark.log
SCRIPT_EOF

chmod +x run_benchmarks.sh

# Debug: Show what we're about to do
echo "Creating tmux session: $SESSION_NAME"
echo "Current directory: \$(pwd)"
echo "Scripts directory exists: \$(ls -la scripts/ | wc -l) files"

# Create tmux session and run the script
if tmux new-session -d -s "$SESSION_NAME" './run_benchmarks.sh'; then
    echo "✅ Tmux session created successfully"
    tmux list-sessions
else
    echo "❌ Failed to create tmux session"
    echo "Trying to run benchmarks directly without tmux..."
    ./run_benchmarks.sh
fi

echo "✅ Benchmarks started in persistent tmux session: $SESSION_NAME"
echo "Session will continue running even if SSH disconnects."
echo ""
echo "Monitor progress with:"
echo "  $0 check $instance_type $instance_ip"
echo "  $0 watch $instance_type $instance_ip"
echo ""
echo "Attach to session with:"
echo "  $0 attach $instance_type $instance_ip"
EOF
}

# Check benchmark progress
check_progress() {
    local instance_type=$1
    local instance_ip=$2
    
    echo "=== Persistent Chameleon Benchmark Collection ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "Session: $SESSION_NAME"
    echo "=== Checking Benchmark Progress ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "Time: $(date)"
    echo ""
    
    ssh -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip" << 'EOF'
cd ~/hw2

echo "=== Active Tmux Sessions ==="
tmux list-sessions 2>/dev/null || echo "No active sessions"
echo ""

echo "=== Recent Benchmark Log (Last 15 lines) ==="
if [ -f benchmark.log ]; then
    tail -15 benchmark.log
else
    echo "No benchmark log found yet"
fi
echo ""

echo "=== Container Status ==="
sudo docker ps -a 2>/dev/null | grep cs553 || echo "No container found"
echo ""

# Check if benchmarks are complete
if tmux list-sessions 2>/dev/null | grep -q hw2_benchmarks; then
    echo "⏳ Benchmarks still running in tmux session"
    echo ""
    echo "To watch in real-time:"
    echo "  bash scripts/collect_chameleon_persistent.sh watch [instance_type] [instance_ip]"
    echo ""
    echo "To attach to session:"
    echo "  bash scripts/collect_chameleon_persistent.sh attach [instance_type] [instance_ip]"
else
    echo "No benchmarks currently running"
    echo ""
    
    if [ -f benchmark.log ] && grep -q "All Benchmarks Complete" benchmark.log; then
        echo "=== Completion Status ==="
        echo "✅ BENCHMARKS COMPLETE! Ready to collect results."
        echo ""
        echo "Run this to collect results:"
        echo "bash scripts/collect_chameleon_persistent.sh collect [instance_type] [instance_ip]"
    fi
fi

echo ""
echo "=== Available Results So Far ==="
if [ -d results ]; then
    ls -la results/ 2>/dev/null || echo "No results directory found"
else
    echo "No results directory found yet"
fi
EOF
}

# Watch benchmark progress in real-time
watch_progress() {
    local instance_type=$1
    local instance_ip=$2
    
    echo "=== Watching Benchmark Progress (Press Ctrl+C to exit) ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo ""
    
    ssh -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip" << 'EOF'
cd ~/hw2

if [ -f benchmark.log ]; then
    echo "Following benchmark log in real-time..."
    echo "Press Ctrl+C to stop watching"
    echo "----------------------------------------"
    tail -f benchmark.log
else
    echo "No benchmark log found yet. Benchmarks may not have started."
fi
EOF
}

# Attach to tmux session
attach_session() {
    local instance_type=$1
    local instance_ip=$2
    
    echo "=== Persistent Chameleon Benchmark Collection ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "Session: $SESSION_NAME"
    echo "=== Attaching to Benchmark Session ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "You will be connected to the live session. Press Ctrl+B then D to detach."
    echo ""
    
    ssh -i "$CHAMELEON_KEY" -t "$CHAMELEON_USER@$instance_ip" << EOF
cd ~/hw2
if tmux list-sessions 2>/dev/null | grep -q hw2_benchmarks; then
    # Find the most recent session
    session=\$(tmux list-sessions | grep hw2_benchmarks | head -1 | cut -d: -f1)
    echo "Attaching to session: \$session"
    tmux attach-session -t "\$session"
else
    echo "No active benchmark session found!"
    echo "Run 'start' command first."
    exit 1
fi
EOF
}

# Collect completed results
collect_results() {
    local instance_type=$1
    local instance_ip=$2
    
    echo "=== Collecting Results from Chameleon Instance ==="
    echo "Instance: $instance_type ($instance_ip)"
    echo "Local directory: $LOCAL_RESULTS_DIR/$instance_type"
    echo ""
    
    # Create local results directory
    mkdir -p "$LOCAL_RESULTS_DIR/$instance_type"
    
    # Download results
    echo "Downloading benchmark results..."
    scp -i "$CHAMELEON_KEY" -r "$CHAMELEON_USER@$instance_ip:~/hw2/results" "$LOCAL_RESULTS_DIR/$instance_type/" 2>/dev/null || echo "No results directory found"
    
    # Download logs
    echo "Downloading benchmark logs..."
    scp -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip:~/hw2/benchmark.log" "$LOCAL_RESULTS_DIR/$instance_type/" 2>/dev/null || echo "No benchmark log found"
    scp -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip:~/hw2/monitoring_*.log" "$LOCAL_RESULTS_DIR/$instance_type/" 2>/dev/null || echo "No monitoring logs found"
    scp -i "$CHAMELEON_KEY" "$CHAMELEON_USER@$instance_ip:~/hw2/system_info_*.txt" "$LOCAL_RESULTS_DIR/$instance_type/" 2>/dev/null || echo "No system info found"
    
    echo ""
    echo "✅ Results collected successfully!"
    echo "Location: $LOCAL_RESULTS_DIR/$instance_type"
    echo ""
    echo "=== Summary of Downloaded Files ==="
    find "$LOCAL_RESULTS_DIR/$instance_type" -type f | head -20
    echo ""
    
    # Count files
    local file_count=$(find "$LOCAL_RESULTS_DIR/$instance_type" -type f | wc -l)
    echo "Total files downloaded: $file_count"
}

# Main function
main() {
    local command=${1:-}
    local instance_type=${2:-}
    local instance_ip=${3:-}
    
    if [ -z "$command" ] || [ -z "$instance_type" ] || [ -z "$instance_ip" ]; then
        usage
        exit 1
    fi
    
    case "$command" in
        "start")
            start_benchmarks "$instance_type" "$instance_ip"
            ;;
        "check")
            check_progress "$instance_type" "$instance_ip"
            ;;
        "watch")
            watch_progress "$instance_type" "$instance_ip"
            ;;
        "attach")
            attach_session "$instance_type" "$instance_ip"
            ;;
        "collect")
            collect_results "$instance_type" "$instance_ip"
            ;;
        *)
            echo "Error: Unknown command '$command'"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
