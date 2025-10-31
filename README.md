# Cloud Computing Environment Performance Benchmark

A comprehensive benchmarking study comparing performance across three computing environments (Bare Metal, Containers, and Virtual Machines) using automated testing on Chameleon Cloud infrastructure.

**Authors**: Likitha Shankar

## Overview

This project evaluates the performance characteristics and virtualization overhead of:
- **Bare Metal**: Direct hardware execution (baseline)
- **Containers**: Docker-based OS-level virtualization
- **Virtual Machines**: LXC-based hardware virtualization

## Key Findings

- **Container Efficiency**: 71.8% - 102.8% of bare metal performance
- **VM Efficiency**: 4.1% - 97.4% of bare metal performance (resource-constrained)
- **Best Performance**: Containers for most workloads, bare metal for maximum throughput
- **Highest Overhead**: Network I/O in virtualized environments

## Benchmarks Conducted

| Test Type | Tool | Measurement |
|-----------|------|------------|
| CPU | sysbench | Prime number calculation, thread scaling |
| Memory | sysbench | Random read throughput (MiB/sec) |
| Disk I/O | sysbench | Random read performance (4KB blocks) |
| Network | iperf3 | TCP loopback bandwidth (Gbits/sec) |

## Project Structure

```
├── HW2_Report.pdf           # Complete analysis and findings
├── Final_Analysis.xlsx      # Consolidated efficiency data
├── plots/                   # Performance visualization graphs
├── scripts/                 # Automated benchmark execution
├── src/                     # Data processing and plotting tools
└── results_chameleon/       # Benchmark data (CSV and raw files)
```

## Installation

### Prerequisites

- Ubuntu 20.04 LTS or later (or compatible Linux distribution)
- Python 3.x with pip
- Docker (for container benchmarks)
- SSH access to Chameleon Cloud instances (for automated benchmarks)

### Setup

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd cs553-fall2025-hw2-liso-main
   ```

2. **Install system dependencies**:
   ```bash
   chmod +x scripts/setup_environment.sh
   ./scripts/setup_environment.sh
   ```

3. **Install Python dependencies**:
   ```bash
   pip3 install -r requirements.txt
   ```

## Usage

### Quick Start

1. **Data Analysis**: Check `Final_Analysis.xlsx` for efficiency calculations
2. **Visualizations**: Browse `plots/` directory for performance graphs
3. **Run Benchmarks**: Use scripts in `scripts/` directory (requires Chameleon Cloud access)

### Running Benchmarks

To run benchmarks on Chameleon Cloud:

1. **Setup bare metal environment**:
   ```bash
   ./scripts/setup_environment.sh
   ```

2. **Setup container environment**:
   ```bash
   ./scripts/setup_chameleon_container.sh <instance-ip>
   ```

3. **Setup VM environment**:
   ```bash
   ./scripts/setup_chameleon_vm.sh <instance-ip>
   ```

4. **Run all benchmarks**:
   ```bash
   ./scripts/collect_chameleon_persistent.sh
   ```

5. **Process and visualize results**:
   ```bash
   python3 src/consolidate_results.py
   python3 src/plot_results.py
   ```

## Main Dependencies

- sysbench (CPU, memory, disk benchmarking)
- iperf3 (network throughput testing)
- Docker (container environment)
- Python 3.x with pandas, matplotlib (data analysis)

## Key Scripts

- `collect_chameleon_persistent.sh` - Main automation framework
- `consolidate_results.py` - Data aggregation and efficiency calculation
- `plot_results.py` - Visualization generation

## Infrastructure

**Platform**: Chameleon Cloud Reserved Instances  
**OS**: Ubuntu 20.04 LTS  
**VM Constraints**: 4 vCPU, 4GiB memory (TA-specified)  
**Test Duration**: 60 seconds per benchmark configuration

## Results Summary

The study demonstrates that containers provide excellent performance with minimal overhead, making them ideal for cloud-native applications. Virtual machines show significant performance degradation under resource constraints but remain valuable for strong isolation requirements.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this work in your research or project, please cite:

```
Shankar, L. (2025). Cloud Computing Environment Performance Benchmark: 
A Comparative Study of Bare Metal, Containers, and Virtual Machines. 
```
