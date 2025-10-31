#!/usr/bin/env python3
"""
Performance Data Consolidation Framework: Aggregates distributed benchmark results with statistical efficiency analysis and cross-environment normalization
Implements automated data validation, baremetal baseline calculation, and structured Excel output for comprehensive virtualization performance evaluation
"""

import pandas as pd
import os
import glob
from pathlib import Path
import argparse

def read_csv_files(directory):
    """Read all CSV files from a directory and combine them."""
    csv_files = glob.glob(os.path.join(directory, "**", "*.csv"), recursive=True)
    
    if not csv_files:
        print(f"Warning: No CSV files found in {directory}")
        return pd.DataFrame()
    
    dataframes = []
    for file in csv_files:
        try:
            df = pd.read_csv(file)
            # Add source file info
            df['source_file'] = os.path.basename(file)
            df['benchmark_type'] = os.path.basename(os.path.dirname(file))
            dataframes.append(df)
            print(f"  ✓ Loaded: {file}")
        except Exception as e:
            print(f"  ✗ Error reading {file}: {e}")
    
    if dataframes:
        return pd.concat(dataframes, ignore_index=True, sort=False)
    else:
        return pd.DataFrame()

def calculate_efficiency(container_df, vm_df, baremetal_df):
    """Calculate efficiency of container and VM relative to baremetal."""
    
    def get_efficiency_for_environment(env_df, baseline_df, env_name):
        """Calculate efficiency for a specific environment."""
        if env_df.empty or baseline_df.empty:
            return env_df
        
        result_df = env_df.copy()
        
        # Calculate efficiency based on benchmark type
        for idx, row in result_df.iterrows():
            benchmark_type = row.get('benchmark_type', '')
            
            if benchmark_type == 'cpu':
                # For CPU: efficiency based on throughput (higher is better)
                threads = row.get('Threads')
                baseline_row = baseline_df[(baseline_df['benchmark_type'] == 'cpu') & (baseline_df['Threads'] == threads)]
                if not baseline_row.empty:
                    baseline_throughput = baseline_row['Measured Throughput (Events per Second)'].iloc[0]
                    env_throughput = row['Measured Throughput (Events per Second)']
                    if baseline_throughput > 0 and pd.notna(env_throughput):
                        efficiency = (env_throughput / baseline_throughput) * 100
                        result_df.at[idx, 'Efficiency'] = round(efficiency, 2)
                    else:
                        result_df.at[idx, 'Efficiency'] = 0.0
            
            elif benchmark_type == 'memory':
                # For Memory: efficiency based on throughput (higher is better)
                threads = row.get('Threads')
                baseline_row = baseline_df[(baseline_df['benchmark_type'] == 'memory') & (baseline_df['Threads'] == threads)]
                if not baseline_row.empty:
                    baseline_throughput = baseline_row['Throughput (MiB/sec)'].iloc[0]
                    env_throughput = row['Throughput (MiB/sec)']
                    if baseline_throughput > 0 and pd.notna(env_throughput):
                        efficiency = (env_throughput / baseline_throughput) * 100
                        result_df.at[idx, 'Efficiency'] = round(efficiency, 2)
                    else:
                        result_df.at[idx, 'Efficiency'] = 0.0
            
            elif benchmark_type == 'disk':
                # For Disk: efficiency based on throughput (higher is better)
                threads = row.get('Threads')
                baseline_row = baseline_df[(baseline_df['benchmark_type'] == 'disk') & (baseline_df['Threads'] == threads)]
                if not baseline_row.empty:
                    baseline_throughput = baseline_row['Measured Throughput (MiB/s)'].iloc[0]
                    env_throughput = row['Measured Throughput (MiB/s)']
                    if baseline_throughput > 0 and pd.notna(env_throughput):
                        efficiency = (env_throughput / baseline_throughput) * 100
                        result_df.at[idx, 'Efficiency'] = round(efficiency, 2)
                    else:
                        result_df.at[idx, 'Efficiency'] = 0.0
            
            elif benchmark_type == 'network':
                # For Network: efficiency based on throughput (higher is better)
                client_threads = row.get('Client Threads')
                baseline_row = baseline_df[(baseline_df['benchmark_type'] == 'network') & (baseline_df['Client Threads'] == client_threads)]
                if not baseline_row.empty:
                    baseline_throughput = baseline_row['Measured Throughput (Gbits/s)'].iloc[0]
                    env_throughput = row['Measured Throughput (Gbits/s)']
                    if baseline_throughput > 0 and pd.notna(env_throughput):
                        efficiency = (env_throughput / baseline_throughput) * 100
                        result_df.at[idx, 'Efficiency'] = round(efficiency, 2)
                    else:
                        result_df.at[idx, 'Efficiency'] = 0.0
        
        return result_df
    
    # Calculate efficiency for container and VM
    container_with_eff = get_efficiency_for_environment(container_df, baremetal_df, "Container")
    vm_with_eff = get_efficiency_for_environment(vm_df, baremetal_df, "VM")
    
    return container_with_eff, vm_with_eff

def create_benchmark_sheets(baremetal_df, container_df, vm_df):
    """Create separate sheets for each benchmark type matching the assignment format."""
    
    sheets = {}
    
    # CPU Benchmark Sheet
    print("  📊 Creating CPU sheet...")
    cpu_data = []
    cpu_bare = baremetal_df[baremetal_df['benchmark_type'] == 'cpu'].copy() if not baremetal_df.empty else pd.DataFrame()
    cpu_cont = container_df[container_df['benchmark_type'] == 'cpu'].copy() if not container_df.empty else pd.DataFrame()
    cpu_vm = vm_df[vm_df['benchmark_type'] == 'cpu'].copy() if not vm_df.empty else pd.DataFrame()
    
    # Get all thread counts
    all_threads = set()
    for df in [cpu_bare, cpu_cont, cpu_vm]:
        if not df.empty and 'Threads' in df.columns:
            all_threads.update(df['Threads'].unique())
    
    for threads in sorted(all_threads):
        # Baremetal row
        bare_row = cpu_bare[cpu_bare['Threads'] == threads]
        if not bare_row.empty:
            cpu_data.append({
                'Virtualization Type': 'Baremetal',
                'Threads': threads,
                'Avg. Latency (ms)': bare_row['Avg. Latency (ms)'].iloc[0],
                'Measured Throughput (Events per Second)': bare_row['Measured Throughput (Events per Second)'].iloc[0],
                'Overheads': '100.00%'
            })
        
        # Container row
        cont_row = cpu_cont[cpu_cont['Threads'] == threads]
        if not cont_row.empty:
            # Calculate efficiency if not already present
            efficiency = None
            if 'Efficiency' in cont_row.columns and pd.notna(cont_row['Efficiency'].iloc[0]):
                efficiency = cont_row['Efficiency'].iloc[0]
            else:
                # Calculate efficiency vs baremetal
                bare_match = cpu_bare[cpu_bare['Threads'] == threads]
                if not bare_match.empty:
                    baseline_throughput = bare_match['Measured Throughput (Events per Second)'].iloc[0]
                    container_throughput = cont_row['Measured Throughput (Events per Second)'].iloc[0]
                    if baseline_throughput > 0 and pd.notna(container_throughput):
                        efficiency = (container_throughput / baseline_throughput) * 100
                    else:
                        efficiency = 0.0
                else:
                    efficiency = 0.0
            
            overhead = f"{efficiency:.2f}%" if efficiency is not None else ""
            cpu_data.append({
                'Virtualization Type': 'Container',
                'Threads': threads,
                'Avg. Latency (ms)': cont_row['Avg. Latency (ms)'].iloc[0],
                'Measured Throughput (Events per Second)': cont_row['Measured Throughput (Events per Second)'].iloc[0],
                'Overheads': overhead
            })
        
        # VM row
        if not cpu_vm.empty and 'Threads' in cpu_vm.columns:
            vm_row = cpu_vm[cpu_vm['Threads'] == threads]
        else:
            vm_row = pd.DataFrame()
        if not vm_row.empty:
            # Calculate efficiency if not already present
            efficiency = None
            if 'Efficiency' in vm_row.columns and pd.notna(vm_row['Efficiency'].iloc[0]):
                efficiency = vm_row['Efficiency'].iloc[0]
            else:
                # Calculate efficiency vs baremetal
                bare_match = cpu_bare[cpu_bare['Threads'] == threads]
                if not bare_match.empty:
                    baseline_throughput = bare_match['Measured Throughput (Events per Second)'].iloc[0]
                    vm_throughput = vm_row['Measured Throughput (Events per Second)'].iloc[0]
                    if baseline_throughput > 0 and pd.notna(vm_throughput):
                        efficiency = (vm_throughput / baseline_throughput) * 100
                    else:
                        efficiency = 0.0
                else:
                    efficiency = 0.0
            
            overhead = f"{efficiency:.2f}%" if efficiency is not None else ""
            cpu_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Avg. Latency (ms)': vm_row['Avg. Latency (ms)'].iloc[0],
                'Measured Throughput (Events per Second)': vm_row['Measured Throughput (Events per Second)'].iloc[0],
                'Overheads': overhead
            })
        else:
            cpu_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Avg. Latency (ms)': '',
                'Measured Throughput (Events per Second)': '',
                'Overheads': ''
            })
    
    sheets['CPU'] = pd.DataFrame(cpu_data)
    
    # Memory Benchmark Sheet
    print("  📊 Creating Memory sheet...")
    memory_data = []
    mem_bare = baremetal_df[baremetal_df['benchmark_type'] == 'memory'].copy() if not baremetal_df.empty else pd.DataFrame()
    mem_cont = container_df[container_df['benchmark_type'] == 'memory'].copy() if not container_df.empty else pd.DataFrame()
    mem_vm = vm_df[vm_df['benchmark_type'] == 'memory'].copy() if not vm_df.empty else pd.DataFrame()
    
    all_threads = set()
    for df in [mem_bare, mem_cont, mem_vm]:
        if not df.empty and 'Threads' in df.columns:
            all_threads.update(df['Threads'].unique())
    
    for threads in sorted(all_threads):
        # Baremetal row
        bare_row = mem_bare[mem_bare['Threads'] == threads]
        if not bare_row.empty:
            memory_data.append({
                'Virtualization Type': 'Baremetal',
                'Threads': threads,
                'Block Size (KB)': bare_row['Block Size (KB)'].iloc[0],
                'Operation': bare_row['Operation'].iloc[0],
                'Access Pattern': bare_row['Access Pattern'].iloc[0],
                'Total Operations': bare_row['Total Operations'].iloc[0],
                'Throughput (MiB/sec)': bare_row['Throughput (MiB/sec)'].iloc[0],
                'Efficiency': '100.00'
            })
        
        # Container row
        cont_row = mem_cont[mem_cont['Threads'] == threads]
        if not cont_row.empty:
            efficiency = cont_row['Efficiency'].iloc[0] if 'Efficiency' in cont_row.columns else 100.00
            memory_data.append({
                'Virtualization Type': 'Container',
                'Threads': threads,
                'Block Size (KB)': cont_row['Block Size (KB)'].iloc[0],
                'Operation': cont_row['Operation'].iloc[0],
                'Access Pattern': cont_row['Access Pattern'].iloc[0],
                'Total Operations': cont_row['Total Operations'].iloc[0],
                'Throughput (MiB/sec)': cont_row['Throughput (MiB/sec)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}"
            })
        
        # VM row
        if not mem_vm.empty and 'Threads' in mem_vm.columns:
            vm_row = mem_vm[mem_vm['Threads'] == threads]
        else:
            vm_row = pd.DataFrame()
        if not vm_row.empty:
            efficiency = vm_row['Efficiency'].iloc[0] if 'Efficiency' in vm_row.columns and pd.notna(vm_row['Efficiency'].iloc[0]) else ''
            memory_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Block Size (KB)': vm_row['Block Size (KB)'].iloc[0],
                'Operation': vm_row['Operation'].iloc[0],
                'Access Pattern': vm_row['Access Pattern'].iloc[0],
                'Total Operations': vm_row['Total Operations'].iloc[0],
                'Throughput (MiB/sec)': vm_row['Throughput (MiB/sec)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}" if efficiency != '' else ''
            })
        else:
            memory_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Block Size (KB)': 1,
                'Operation': 'Read',
                'Access Pattern': 'Random',
                'Total Operations': '',
                'Throughput (MiB/sec)': '',
                'Efficiency': ''
            })
    
    sheets['Memory'] = pd.DataFrame(memory_data)
    
    # Disk Benchmark Sheet
    print("  📊 Creating Disk sheet...")
    disk_data = []
    disk_bare = baremetal_df[baremetal_df['benchmark_type'] == 'disk'].copy() if not baremetal_df.empty else pd.DataFrame()
    disk_cont = container_df[container_df['benchmark_type'] == 'disk'].copy() if not container_df.empty else pd.DataFrame()
    disk_vm = vm_df[vm_df['benchmark_type'] == 'disk'].copy() if not vm_df.empty else pd.DataFrame()
    
    all_threads = set()
    for df in [disk_bare, disk_cont, disk_vm]:
        if not df.empty and 'Threads' in df.columns:
            all_threads.update(df['Threads'].unique())
    
    for threads in sorted(all_threads):
        # Baremetal row
        bare_row = disk_bare[disk_bare['Threads'] == threads]
        if not bare_row.empty:
            disk_data.append({
                'Virtualization Type': 'Baremetal',
                'Threads': threads,
                'Block Size (KB)': bare_row['Block Size (KB)'].iloc[0],
                'Operation': bare_row['Operation'].iloc[0],
                'Access Pattern': bare_row['Access Pattern'].iloc[0],
                'I/O Mode': bare_row['I/O Mode'].iloc[0],
                'I/O Flag': bare_row['I/O Flag'].iloc[0],
                'Total Operations': bare_row['Total Operations'].iloc[0],
                'Measured Throughput (MiB/s)': bare_row['Measured Throughput (MiB/s)'].iloc[0],
                'Efficiency': '100.00'
            })
        
        # Container row
        cont_row = disk_cont[disk_cont['Threads'] == threads]
        if not cont_row.empty:
            efficiency = cont_row['Efficiency'].iloc[0] if 'Efficiency' in cont_row.columns else 100.00
            disk_data.append({
                'Virtualization Type': 'Container',
                'Threads': threads,
                'Block Size (KB)': cont_row['Block Size (KB)'].iloc[0],
                'Operation': cont_row['Operation'].iloc[0],
                'Access Pattern': cont_row['Access Pattern'].iloc[0],
                'I/O Mode': cont_row['I/O Mode'].iloc[0],
                'I/O Flag': cont_row['I/O Flag'].iloc[0],
                'Total Operations': cont_row['Total Operations'].iloc[0],
                'Measured Throughput (MiB/s)': cont_row['Measured Throughput (MiB/s)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}"
            })
        
        # VM row
        if not disk_vm.empty and 'Threads' in disk_vm.columns:
            vm_row = disk_vm[disk_vm['Threads'] == threads]
        else:
            vm_row = pd.DataFrame()
        if not vm_row.empty:
            efficiency = vm_row['Efficiency'].iloc[0] if 'Efficiency' in vm_row.columns and pd.notna(vm_row['Efficiency'].iloc[0]) else ''
            disk_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Block Size (KB)': vm_row['Block Size (KB)'].iloc[0],
                'Operation': vm_row['Operation'].iloc[0],
                'Access Pattern': vm_row['Access Pattern'].iloc[0],
                'I/O Mode': vm_row['I/O Mode'].iloc[0],
                'I/O Flag': vm_row['I/O Flag'].iloc[0],
                'Total Operations': vm_row['Total Operations'].iloc[0],
                'Measured Throughput (MiB/s)': vm_row['Measured Throughput (MiB/s)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}" if efficiency != '' else ''
            })
        else:
            disk_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Threads': threads,
                'Block Size (KB)': 4,
                'Operation': 'Read',
                'Access Pattern': 'Random',
                'I/O Mode': 'SYNC',
                'I/O Flag': 'DirectIO',
                'Total Operations': '',
                'Measured Throughput (MiB/s)': '',
                'Efficiency': ''
            })
    
    sheets['Disk'] = pd.DataFrame(disk_data)
    
    # Network Benchmark Sheet
    print("  📊 Creating Network sheet...")
    network_data = []
    net_bare = baremetal_df[baremetal_df['benchmark_type'] == 'network'].copy() if not baremetal_df.empty else pd.DataFrame()
    net_cont = container_df[container_df['benchmark_type'] == 'network'].copy() if not container_df.empty else pd.DataFrame()
    net_vm = vm_df[vm_df['benchmark_type'] == 'network'].copy() if not vm_df.empty else pd.DataFrame()
    
    # Filter out rows with NaN throughput values for container data
    if not net_cont.empty:
        net_cont = net_cont[pd.notna(net_cont['Measured Throughput (Gbits/s)'])]
    
    all_threads = set()
    for df in [net_bare, net_cont, net_vm]:
        if not df.empty and 'Client Threads' in df.columns:
            all_threads.update(df['Client Threads'].unique())
    
    for threads in sorted(all_threads):
        # Baremetal row
        bare_row = net_bare[net_bare['Client Threads'] == threads]
        if not bare_row.empty:
            network_data.append({
                'Virtualization Type': 'Baremetal',
                'Server': bare_row['Server'].iloc[0],
                'Client Threads': threads,
                'Latency (ms)': bare_row['Latency (ms)'].iloc[0],
                'Measured Throughput (Gbits/s)': bare_row['Measured Throughput (Gbits/s)'].iloc[0],
                'Efficiency': '100.00'
            })
        
        # Container row
        cont_row = net_cont[net_cont['Client Threads'] == threads]
        if not cont_row.empty:
            # Calculate efficiency
            bare_match = net_bare[net_bare['Client Threads'] == threads]
            if not bare_match.empty:
                baseline_throughput = bare_match['Measured Throughput (Gbits/s)'].iloc[0]
                container_throughput = cont_row['Measured Throughput (Gbits/s)'].iloc[0]
                if baseline_throughput > 0 and pd.notna(container_throughput):
                    efficiency = (container_throughput / baseline_throughput) * 100
                else:
                    efficiency = 0.0
            else:
                efficiency = 0.0
            
            network_data.append({
                'Virtualization Type': 'Container',
                'Server': cont_row['Server'].iloc[0],
                'Client Threads': threads,
                'Latency (ms)': cont_row['Latency (ms)'].iloc[0],
                'Measured Throughput (Gbits/s)': cont_row['Measured Throughput (Gbits/s)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}"
            })
        
        # VM row
        if not net_vm.empty and 'Client Threads' in net_vm.columns:
            vm_row = net_vm[net_vm['Client Threads'] == threads]
        else:
            vm_row = pd.DataFrame()
        if not vm_row.empty:
            # Calculate efficiency
            bare_match = net_bare[net_bare['Client Threads'] == threads]
            if not bare_match.empty:
                baseline_throughput = bare_match['Measured Throughput (Gbits/s)'].iloc[0]
                vm_throughput = vm_row['Measured Throughput (Gbits/s)'].iloc[0]
                if baseline_throughput > 0 and pd.notna(vm_throughput):
                    efficiency = (vm_throughput / baseline_throughput) * 100
                else:
                    efficiency = 0.0
            else:
                efficiency = 0.0
            
            network_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Server': vm_row['Server'].iloc[0],
                'Client Threads': threads,
                'Latency (ms)': vm_row['Latency (ms)'].iloc[0],
                'Measured Throughput (Gbits/s)': vm_row['Measured Throughput (Gbits/s)'].iloc[0],
                'Efficiency': f"{efficiency:.2f}"
            })
        else:
            network_data.append({
                'Virtualization Type': 'Virtual Machine',
                'Server': 1,
                'Client Threads': threads,
                'Latency (ms)': '',
                'Measured Throughput (Gbits/s)': '',
                'Efficiency': ''
            })
    
    sheets['Network'] = pd.DataFrame(network_data)
    
    return sheets

def create_summary_sheet(benchmark_sheets):
    """Create an overall summary sheet from benchmark sheets."""
    summary_data = []
    
    for bench_type, df in benchmark_sheets.items():
        if df.empty:
            continue
            
        row = {'Benchmark': bench_type}
        
        # Find performance columns (exclude efficiency columns)
        perf_cols = [col for col in df.columns if not col.endswith('_Efficiency_%') and col != 'Threads']
        
        # Calculate averages for each environment
        for env in ['Baremetal', 'Container', 'VM']:
            env_cols = [col for col in perf_cols if col.startswith(f'{env}_')]
            if env_cols:
                # Get average of primary metric (usually first metric)
                primary_col = env_cols[0] if env_cols else None
                if primary_col and primary_col in df.columns:
                    avg_val = df[primary_col].dropna().mean()
                    row[f'{env}_Avg'] = round(avg_val, 2) if pd.notna(avg_val) else 'N/A'
                else:
                    row[f'{env}_Avg'] = 'N/A'
            else:
                row[f'{env}_Avg'] = 'N/A'
        
        # Add efficiency averages
        for env in ['Container', 'VM']:
            eff_cols = [col for col in df.columns if col.startswith(f'{env}_') and col.endswith('_Efficiency_%')]
            if eff_cols:
                # Average all efficiency metrics
                all_effs = []
                for col in eff_cols:
                    all_effs.extend(df[col].dropna().tolist())
                if all_effs:
                    avg_eff = sum(all_effs) / len(all_effs)
                    row[f'{env}_Avg_Efficiency_%'] = round(avg_eff, 1)
                else:
                    row[f'{env}_Avg_Efficiency_%'] = 'N/A'
            else:
                row[f'{env}_Avg_Efficiency_%'] = 'N/A'
        
        summary_data.append(row)
    
    return pd.DataFrame(summary_data)

def main():
    parser = argparse.ArgumentParser(description='Consolidate CS553 benchmark results')
    parser.add_argument('--results-dir', default='results_chameleon', 
                       help='Results directory (default: results_chameleon)')
    parser.add_argument('--output', default='Final_Analysis.xlsx',
                       help='Output Excel file (default: Final_Analysis.xlsx)')
    
    args = parser.parse_args()
    
    results_dir = Path(args.results_dir)
    output_file = args.output
    
    if not results_dir.exists():
        print(f"Error: Results directory '{results_dir}' not found!")
        print("Make sure you've downloaded results using scp commands.")
        return
    
    print("🔍 CS553 HW#2 Results Consolidation")
    print("=" * 50)
    
    # Read data from each environment
    print("\n📊 Reading benchmark data...")
    
    baremetal_dir = results_dir / "baremetal"
    container_dir = results_dir / "container" 
    vm_dir = results_dir / "vm"
    
    print(f"\n🖥️  Loading baremetal results from {baremetal_dir}...")
    baremetal_df = read_csv_files(baremetal_dir)
    
    print(f"\n🐳 Loading container results from {container_dir}...")
    container_df = read_csv_files(container_dir)
    
    print(f"\n🖥️  Loading VM results from {vm_dir}...")
    vm_df = read_csv_files(vm_dir)
    
    # Check if we have data
    if baremetal_df.empty:
        print("❌ No baremetal data found! Cannot calculate efficiency.")
        return
    
    print(f"\n📈 Calculating efficiency metrics...")
    print("   (Container and VM performance relative to baremetal)")
    
    # Calculate efficiency
    container_with_eff, vm_with_eff = calculate_efficiency(container_df, vm_df, baremetal_df)
    
    # Create benchmark-specific sheets
    print(f"\n📋 Creating benchmark sheets...")
    benchmark_sheets = create_benchmark_sheets(baremetal_df, container_with_eff, vm_with_eff)
    
    # Write to Excel
    print(f"\n💾 Writing results to {output_file}...")
    
    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
        # Only benchmark-specific sheets (no summary or raw data)
        for bench_name, bench_df in benchmark_sheets.items():
            if not bench_df.empty:
                bench_df.to_excel(writer, sheet_name=bench_name, index=False)
                print(f"  ✓ {bench_name} sheet created")
    
    print(f"\n✅ Results consolidated successfully!")
    print(f"📁 Output file: {output_file}")
    print("\n📊 Excel sheets created:")
    print("   • CPU - CPU benchmark results with efficiency calculations") 
    print("   • Memory - Memory benchmark results with efficiency calculations")
    print("   • Network - Network benchmark results with efficiency calculations")
    print("   • Disk - Disk benchmark results with efficiency calculations")
    print("\n🎯 Format matches assignment requirements with calculated efficiency values")

if __name__ == "__main__":
    main()
