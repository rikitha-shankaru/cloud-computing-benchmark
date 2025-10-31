#!/bin/bash

set -e

# CPU Performance Analysis: Quantifies computational throughput and virtualization overhead using sysbench prime calculation
# Evaluates thread scaling behavior across baremetal, container, and VM environments for comparative performance analysis

ENVIRONMENT=$1
TIMESTAMP=${2:-$(date +%Y%m%d_%H%M%S)}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: baremetal, container, vm"
    exit 1
fi

PRIME_LIMIT=100000
THREADS=(1 2 4 8 16 32 64)

echo "Running CPU benchmark for: $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"

run_cpu_test() {
    local env=$1
    local threads=$2
    local output_file=$3
    
    echo "Testing $threads threads"
    
    if [ "$env" = "baremetal" ]; then
        sysbench cpu --cpu-max-prime=$PRIME_LIMIT --threads=$threads run > "$output_file"
    elif [ "$env" = "container" ]; then
        sudo docker exec cs553-container sysbench cpu --cpu-max-prime=$PRIME_LIMIT --threads=$threads run > "$output_file"
    elif [ "$env" = "vm" ]; then
        sudo lxc exec cs553-vm -- sysbench cpu --cpu-max-prime=$PRIME_LIMIT --threads=$threads run > "$output_file"
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
    
    local events_per_sec=$(grep "events per second:" "$file" | awk '{print $4}')
    local avg_latency=$(grep "avg:" "$file" | awk '{print $2}')
    
    # Efficiency will be calculated later in post-processing
    local efficiency=""
    
    echo "$env,$threads,$avg_latency,$events_per_sec,$efficiency" >> "$SUMMARY_FILE"
    
    echo "Results: $events_per_sec events/sec, $avg_latency ms"
}

mkdir -p results/${ENVIRONMENT}/cpu

# Create result files  
SUMMARY_FILE="results/${ENVIRONMENT}/cpu/cpu_summary_${TIMESTAMP}.csv"
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "Virtualization Type,Threads,Avg. Latency (ms),Measured Throughput (Events per Second),Efficiency" > "$SUMMARY_FILE"
fi

# Save system info
SYSTEM_FILE="results/${ENVIRONMENT}/cpu/system_${ENVIRONMENT}_${TIMESTAMP}.txt"
{
    echo "Environment: $ENVIRONMENT"
    echo "Date: $(date)"
    echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | tr -s ' ')"
    echo "Cores: $(nproc)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
} > "$SYSTEM_FILE"

echo "Starting tests..."

for thread_count in "${THREADS[@]}"; do
    output_file="results/${ENVIRONMENT}/cpu/raw_${ENVIRONMENT}_${thread_count}threads_${TIMESTAMP}.txt"
    
    run_cpu_test "$ENVIRONMENT" "$thread_count" "$output_file"
    parse_results "$output_file" "$ENVIRONMENT" "$thread_count"
    
    sleep 2
done

echo "CPU benchmark completed for $ENVIRONMENT"
echo "Results saved to: $SUMMARY_FILE"
echo "Note: Efficiency calculations will be done in post-processing"
