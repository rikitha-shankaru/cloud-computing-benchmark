#!/bin/bash

set -e

echo "Setting up CS553 HW2 benchmarking environment..."

# install packages
echo "Installing packages..."
sudo apt update
sudo apt install -y sysbench iperf tmux docker.io python3 python3-pip

# python packages
pip3 install matplotlib pandas numpy seaborn

# setup docker
echo "Setting up Docker..."
sudo usermod -aG docker $USER
sudo docker pull ubuntu:24.04

# create benchmark container
sudo docker run -d --name benchmark-container --privileged ubuntu:24.04 sleep infinity

# install tools in container
sudo docker exec benchmark-container bash -c "apt update && apt install -y sysbench iperf"

# create directories
echo "Creating directories..."
mkdir -p results/cpu results/memory results/disk results/network
mkdir -p plots

echo "System info:"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | tr -s ' ')"
echo "Cores: $(nproc)"  
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"

echo "Setup done!"
echo "NOTE: You need to setup VM manually with Ubuntu 24.04"
echo "Install sysbench and iperf in the VM too"

echo "Setup completed on $(date)" > setup_status.txt
