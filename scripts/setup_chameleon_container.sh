#!/bin/bash

# Simple Container Setup for CS553 HW#2
# This script creates a Docker container on Chameleon Cloud for benchmarking

# Basic settings
CHAMELEON_USER="cc"
CHAMELEON_KEY="~/.ssh/id_ed25519"
CONTAINER_NAME="cs553-container"

# Check if user provided the IP address
if [ $# -ne 1 ]; then
    echo "Usage: $0 <chameleon_ip>"
    echo "Example: $0 129.114.108.206"
    exit 1
fi

INSTANCE_IP=$1

echo "Setting up container on Chameleon instance: $INSTANCE_IP"

# Simple function to run commands on remote server
run_on_server() {
    ssh -i "$CHAMELEON_KEY" -o StrictHostKeyChecking=no "$CHAMELEON_USER@$INSTANCE_IP" "$1"
}

# Step 1: Install Docker (simple version)
echo "Step 1: Installing Docker..."
run_on_server "sudo apt update && sudo apt install -y docker.io"
run_on_server "sudo systemctl start docker"
echo "Docker installed!"

# Step 2: Create a simple container
echo "Step 2: Creating container..."
run_on_server "sudo docker rm -f $CONTAINER_NAME 2>/dev/null || true"
run_on_server "sudo docker run -d --name $CONTAINER_NAME --privileged ubuntu:latest sleep infinity"
echo "Container '$CONTAINER_NAME' created!"

# Step 3: Install benchmark tools in container
echo "Step 3: Installing benchmark tools..."
run_on_server "sudo docker exec $CONTAINER_NAME apt update"
run_on_server "sudo docker exec $CONTAINER_NAME apt install -y sysbench iperf3 iperf bc netcat-openbsd net-tools"
echo "Benchmark tools installed!"

# Step 4: Copy scripts to container
echo "Step 4: Setting up benchmark scripts..."
run_on_server "sudo docker exec $CONTAINER_NAME mkdir -p /hw2_benchmarks/results"
run_on_server "sudo docker cp ~/hw2_benchmarks/scripts $CONTAINER_NAME:/hw2_benchmarks/"
run_on_server "sudo docker exec $CONTAINER_NAME chmod +x /hw2_benchmarks/scripts/*.sh"
echo "Scripts ready!"

# Step 5: Test everything works
echo "Step 5: Testing container..."
run_on_server "sudo docker exec $CONTAINER_NAME echo 'Container is working!'"
run_on_server "sudo docker exec $CONTAINER_NAME sysbench --version | head -1"

echo ""
echo "âœ… Container setup complete!"
echo "Container name: $CONTAINER_NAME"
echo ""
echo "Next step: Run benchmarks with:"
echo "bash scripts/collect_chameleon_persistent.sh start container $INSTANCE_IP"
echo ""
echo "Useful container commands:"
echo "  sudo docker exec -it $CONTAINER_NAME bash    # Enter container"
echo "  sudo docker ps                               # List containers"
echo "  sudo docker logs $CONTAINER_NAME             # View logs"
