#!/bin/bash

# CS553 HW#2 - LXC Virtual Machine Setup for Chameleon Cloud

set -e

# Configuration constants
CHAMELEON_USER="cc"
CHAMELEON_KEY="~/.ssh/id_ed25519"
VM_NAME="cs553-vm"

# Input validation
if [ $# -ne 1 ]; then
    echo "Usage: $0 <chameleon_ip>"
    echo "Example: $0 129.114.108.206"
    exit 1
fi

INSTANCE_IP=$1
echo "Setting up VM on Chameleon instance: $INSTANCE_IP"

# Helper functions for remote command execution
run_on_server() {
    ssh -i "$CHAMELEON_KEY" -o StrictHostKeyChecking=no "$CHAMELEON_USER@$INSTANCE_IP" "$1"
}

run_on_server_output() {
    ssh -i "$CHAMELEON_KEY" -o StrictHostKeyChecking=no "$CHAMELEON_USER@$INSTANCE_IP" "$1"
}

echo "🔧 CS553 HW#2 VM Setup"
echo "====================="

# Update system packages
echo "Step 1: Updating system packages..."
run_on_server "sudo apt update && sudo apt upgrade -y"
echo "✓ System updated"

# Install LXD using snap and required network tools
echo "Step 2: Installing LXD and dependencies..."
run_on_server "sudo snap install lxd"
run_on_server "sudo apt install -y dnsmasq"
echo "✓ LXD and dependencies installed"

# Add user to lxd group for permissions
echo "Step 3: Configuring LXD permissions..."
run_on_server "sudo usermod -a -G lxd cc"
echo "✓ User added to lxd group"

# Initialize LXD with simple auto configuration
echo "Step 4: Initializing LXD..."
run_on_server "sudo lxd init --auto"
echo "✓ LXD initialized"

# Fix networking issues
echo "Step 5: Fixing network configuration..."
run_on_server "sudo systemctl stop firewalld 2>/dev/null || true"
run_on_server "sudo systemctl disable firewalld 2>/dev/null || true"
echo "✓ Firewall issues resolved"

# Download Ubuntu 24.04 image for VMs
echo "Step 6: Downloading Ubuntu 24.04 VM image..."
run_on_server "sudo lxc image copy ubuntu:24.04 local: --vm --alias ubuntu24-vm"
echo "✓ Ubuntu 24.04 VM image downloaded"

# Create VM with assignment specifications (4 CPUs, 4GiB memory)
echo "Step 7: Creating VM '$VM_NAME'..."
echo "Using Ubuntu 24.04 with 4 CPUs and 4GiB memory..."

# Remove existing VM if present
run_on_server "sudo lxc delete $VM_NAME --force 2>/dev/null || true"

# Create VM with assignment specifications
run_on_server "sudo lxc launch ubuntu24-vm $VM_NAME --vm -c limits.cpu=4 -c limits.memory=4GiB"

# Wait for VM to start and initialize
echo "Waiting for VM to start and initialize..."
sleep 45

# Verify VM is running
echo "Checking VM status..."
run_on_server_output "sudo lxc list"
echo "Step 5: Creating VM '$VM_NAME'..."
echo "Using Ubuntu 24.04 with 4 CPUs and 4GiB memory..."

# Remove existing VM if present
run_on_server "sudo lxc delete $VM_NAME --force 2>/dev/null || true"

# Launch VM with resource limits
run_on_server "sudo lxc launch ubuntu:24.04 $VM_NAME --vm -c limits.cpu=4 -c limits.memory=4GiB"

# Wait for VM initialization
echo "Waiting for VM to start..."
sleep 30

# Verify VM status
echo "Checking VM status..."
run_on_server_output "sudo lxc list"

# Install benchmark tools in VM
echo "Step 6: Installing benchmark tools in VM..."
echo "Waiting for VM to be fully ready..."
sleep 20

# Install benchmark tools
run_on_server "sudo lxc exec $VM_NAME -- apt update"
run_on_server "sudo lxc exec $VM_NAME -- apt install -y sysbench iperf3 iperf bc netcat-openbsd net-tools openssh-server"

# Enable SSH in the VM
run_on_server "sudo lxc exec $VM_NAME -- systemctl enable ssh"
run_on_server "sudo lxc exec $VM_NAME -- systemctl start ssh"

echo "✓ Benchmark tools installed in VM"

# Install benchmark tools in VM
echo "Step 8: Installing benchmark tools in VM..."
echo "Waiting for VM to be fully ready..."
sleep 20

# Update package lists and install tools
run_on_server "sudo lxc exec $VM_NAME -- apt update"
run_on_server "sudo lxc exec $VM_NAME -- apt install -y sysbench iperf3 iperf bc netcat-openbsd net-tools openssh-server"

# Enable SSH in the VM
run_on_server "sudo lxc exec $VM_NAME -- systemctl enable ssh"
run_on_server "sudo lxc exec $VM_NAME -- systemctl start ssh"

echo "✓ Benchmark tools installed in VM"

# Create benchmark directories
echo "Step 9: Setting up benchmark environment in VM..."
run_on_server "sudo lxc exec $VM_NAME -- mkdir -p /hw2_benchmarks/results"

echo "✓ Benchmark environment ready"

# Test VM connectivity and tools
echo "Step 10: Testing VM setup..."

# Test basic connectivity
echo "Testing VM connectivity..."
run_on_server "sudo lxc exec $VM_NAME -- echo 'VM is responsive!'"
run_on_server "sudo lxc exec $VM_NAME -- whoami"
run_on_server "sudo lxc exec $VM_NAME -- uname -a"

# Verify system resources
echo "Verifying VM resources..."
run_on_server "sudo lxc exec $VM_NAME -- nproc"
run_on_server "sudo lxc exec $VM_NAME -- free -h"

# Test benchmark tools
echo "Testing benchmark tools..."
run_on_server "sudo lxc exec $VM_NAME -- sysbench --version | head -1"
run_on_server "sudo lxc exec $VM_NAME -- iperf3 --version | head -1"

echo "✓ VM testing complete"

echo ""
echo "🎉 VM Setup Complete!"
echo "====================="
echo "VM Name: $VM_NAME"
echo "VM IP: $VM_IP"
echo "Resources: 4 CPUs, 4GiB Memory"
echo "Storage: 50GiB (sufficient for disk experiments)"
echo ""
echo "Useful VM management commands:"
echo "  sudo lxc list                           # List all containers/VMs"
echo "  sudo lxc exec $VM_NAME -- bash          # Enter VM shell"
echo "  sudo lxc stop $VM_NAME                  # Stop VM"
echo "  sudo lxc start $VM_NAME                 # Start VM"
echo "  sudo lxc info $VM_NAME                  # VM information"
echo ""
echo "Next step: Run VM benchmarks with:"
echo "bash scripts/collect_chameleon_persistent.sh start vm $INSTANCE_IP"
echo ""
echo "Note: VM is ready for all 4 benchmark types (CPU, Memory, Network, Disk)"
