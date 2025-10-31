#!/bin/bash

set -e

# Storage I/O Performance Analysis: Quantifies disk throughput and IOPS using random read patterns with direct I/O to bypass cache layers
# Evaluates storage virtualization overhead including virtual block device translation and guest-to-host I/O path penalties

ENVIRONMENT=$1
TIMESTAMP=${2:-$(date +%Y%m%d_%H%M%S)}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: baremetal, container, vm"
    exit 1
fi

# Configuration
FILE_NUM=128
FILE_BLOCK_SIZE=4096
FILE_TOTAL_SIZE="120G"
THREADS=(1 2 4 8 16 32 64)

echo "Running Disk benchmark for: $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"

mkdir -p results/${ENVIRONMENT}/disk

# Create summary CSV with assignment table headers
SUMMARY_FILE="results/${ENVIRONMENT}/disk/disk_summary_${TIMESTAMP}.csv"
echo "Virtualization Type,Threads,Block Size (KB),Operation,Access Pattern,I/O Mode,I/O Flag,Total Operations,Measured Throughput (MiB/s),Efficiency" > "$SUMMARY_FILE"

# Function to run a single disk test
run_disk_test() {
    local env=$1
    local threads=$2
    local output_file=$3
    
    echo "Testing $threads threads"
    
    if [ "$env" = "baremetal" ]; then
        sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct --threads=$threads run > "$output_file"
    elif [ "$env" = "container" ]; then
        sudo docker exec cs553-container sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct --threads=$threads run > "$output_file"
    elif [ "$env" = "vm" ]; then
        sudo lxc exec cs553-vm -- sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct --threads=$threads run > "$output_file"
    fi
}

# Function to parse results
parse_disk_results() {
    local file=$1
    local env=$2
    local threads=$3
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return
    fi
    
    # Extract metrics from sysbench output
    local total_ops=$(grep "total number of events:" "$file" | awk '{print $NF}')
    local throughput_mib=$(grep "read, MiB/s:" "$file" | awk -F': ' '{print $2}' | xargs)
    
    # Assignment table fields
    local block_size="4"  # 4KB
    local operation="Read"
    local access_pattern="Random"
    local io_mode="SYNC"
    local io_flag="DirectIO"
    
    # Efficiency will be calculated later (empty for now)
    local efficiency=""
    
    # Output to CSV
    echo "$env,$threads,$block_size,$operation,$access_pattern,$io_mode,$io_flag,$total_ops,$throughput_mib,$efficiency" >> "$SUMMARY_FILE"
    
    echo "Results: $total_ops operations, $throughput_mib MiB/s"
}

echo "Running $ENVIRONMENT disk benchmarks..."

# Prepare test files for all environments
echo "Preparing test files..."

if [ "$ENVIRONMENT" = "baremetal" ]; then
    sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct prepare
elif [ "$ENVIRONMENT" = "container" ]; then
    sudo docker exec cs553-container sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct prepare
elif [ "$ENVIRONMENT" = "vm" ]; then
    sudo lxc exec cs553-vm -- sysbench fileio --file-num=$FILE_NUM --file-block-size=$FILE_BLOCK_SIZE --file-total-size=$FILE_TOTAL_SIZE --file-test-mode=rndrd --file-io-mode=sync --file-extra-flags=direct prepare
fi

echo "Test files prepared successfully."

# Run tests for each thread count
for thread_count in "${THREADS[@]}"; do
    output_file="results/${ENVIRONMENT}/disk/disk_${ENVIRONMENT}_${thread_count}threads_${TIMESTAMP}.txt"
    
    echo "Running disk test: $ENVIRONMENT - $thread_count threads"
    
    run_disk_test "$ENVIRONMENT" "$thread_count" "$output_file"
    parse_disk_results "$output_file" "$ENVIRONMENT" "$thread_count"
    sleep 2
done

# Cleanup test files for all environments
echo "Cleaning up test files..."

if [ "$ENVIRONMENT" = "baremetal" ]; then
    sysbench fileio cleanup
elif [ "$ENVIRONMENT" = "container" ]; then
    sudo docker exec cs553-container sysbench fileio cleanup
elif [ "$ENVIRONMENT" = "vm" ]; then
    sudo lxc exec cs553-vm -- sysbench fileio cleanup
fi

echo "Cleanup completed."

echo "Disk I/O benchmarking completed for $ENVIRONMENT!"
echo "Results in: results/${ENVIRONMENT}/disk/"
echo "Summary: disk_summary_${TIMESTAMP}.csv"
echo "Note: Efficiency calculations will be done in post-processing"
