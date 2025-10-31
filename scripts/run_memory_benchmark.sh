#!/bin/bash

set -e

# Memory Subsystem Analysis: Evaluates memory bandwidth and latency characteristics using random access patterns to stress virtualization layers
# Quantifies memory virtualization overhead including guest-to-host address translation penalties across different abstraction levels

ENVIRONMENT=$1
TIMESTAMP=${2:-$(date +%Y%m%d_%H%M%S)}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: baremetal, container, vm"
    exit 1
fi

TOTAL_SIZE="120G"
BLOCK_SIZE="1K" 
THREADS=(1 2 4 8 16 32 64)

echo "Running Memory benchmark for: $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"

run_memory_test() {
    local env=$1
    local threads=$2
    local output_file=$3
    
    echo "Testing $threads threads"
    
    if [ "$env" = "baremetal" ]; then
        sysbench memory --memory-block-size=$BLOCK_SIZE --memory-total-size=$TOTAL_SIZE --memory-oper=read --memory-access-mode=rnd --threads=$threads run > "$output_file"
    elif [ "$env" = "container" ]; then
        sudo docker exec cs553-container sysbench memory --memory-block-size=$BLOCK_SIZE --memory-total-size=$TOTAL_SIZE --memory-oper=read --memory-access-mode=rnd --threads=$threads run > "$output_file"
    elif [ "$env" = "vm" ]; then
        sudo lxc exec cs553-vm -- sysbench memory --memory-block-size=$BLOCK_SIZE --memory-total-size=$TOTAL_SIZE --memory-oper=read --memory-access-mode=rnd --threads=$threads run > "$output_file"
    fi
}

parse_results() {
    local file=$1
    local env=$2  
    local threads=$3
    
    if [ ! -f "$file" ]; then
        echo "Error: file not found $file"
        return
    fi
    
    # Extract metrics from sysbench output
    local total_ops=$(grep "total number of events:" "$file" | awk '{print $NF}')
    local throughput=$(grep "MiB/sec" "$file" | awk '{print $1}')
    
    # Assignment requirements
    local block_size_kb=1  # 1KB as per assignment
    local operation="Read"  # Read operations as per assignment
    local access_pattern="Random"  # Random access as per assignment
    
    # Efficiency will be calculated later after all environments are tested
    local efficiency=""
    
    echo "$env,$threads,$block_size_kb,$operation,$access_pattern,$total_ops,$throughput,$efficiency" >> "$SUMMARY_FILE"
    
    echo "Results: $throughput MiB/sec, $total_ops operations"
}

mkdir -p results/${ENVIRONMENT}/memory

# Create result files  
SUMMARY_FILE="results/${ENVIRONMENT}/memory/memory_summary_${TIMESTAMP}.csv"
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "Virtualization Type,Threads,Block Size (KB),Operation,Access Pattern,Total Operations,Throughput (MiB/sec),Efficiency" > "$SUMMARY_FILE"
fi

# Save system info
SYSTEM_FILE="results/${ENVIRONMENT}/memory/system_${ENVIRONMENT}_${TIMESTAMP}.txt"
{
    echo "Environment: $ENVIRONMENT"
    echo "Date: $(date)"
    echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | tr -s ' ')"
    echo "Cores: $(nproc)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
} > "$SYSTEM_FILE"

echo "Starting tests..."

for thread_count in "${THREADS[@]}"; do
    output_file="results/${ENVIRONMENT}/memory/raw_${ENVIRONMENT}_${thread_count}threads_${TIMESTAMP}.txt"
    
    run_memory_test "$ENVIRONMENT" "$thread_count" "$output_file"
    parse_results "$output_file" "$ENVIRONMENT" "$thread_count"
    
    sleep 2
done

echo "Memory benchmark completed for $ENVIRONMENT"
echo "Results saved to: $SUMMARY_FILE"
echo "Note: Efficiency calculations will be done in post-processing"
