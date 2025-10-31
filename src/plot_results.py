#!/usr/bin/env python3
"""
Performance Visualization Framework: Generates publication-quality plots with perceptually-uniform color encoding for comparative virtualization analysis
Implements academic visualization standards including accessibility compliance and statistical accuracy for performance data presentation
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Clear plotting configuration - optimized for readability
plt.rcParams.update({
    'font.size': 11,
    'font.family': 'Arial',
    'figure.figsize': (14, 8),
    'axes.labelsize': 12,
    'axes.titlesize': 14,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 11,
    'lines.linewidth': 2.5,
    'lines.markersize': 8,
    'grid.alpha': 0.3,
    'axes.grid': True,
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'figure.dpi': 100
})

# Clean color scheme - distinct and accessible
COLORS = {
    'Baremetal': '#2E86AB',        # Deep blue
    'Container': '#A23B72',        # Deep magenta  
    'Virtual Machine': '#F18F01',  # Orange
    'VM': '#F18F01'               # Alias for VM
}

MARKERS = {
    'Baremetal': 'o',
    'Container': 's', 
    'Virtual Machine': '^',
    'VM': '^'
}

def load_data_from_excel(excel_file):
    """Load data from the consolidated Excel file."""
    try:
        sheets = pd.read_excel(excel_file, sheet_name=None)
        print(f"✅ Loaded Excel file with sheets: {list(sheets.keys())}")
        return sheets
    except Exception as e:
        print(f"❌ Error loading Excel file: {e}")
        return None

def setup_clean_plot(ax, title, xlabel, ylabel, log_scale=False):
    """Apply clean, readable styling to plots."""
    ax.set_title(title, fontsize=14, fontweight='bold', pad=15)
    ax.set_xlabel(xlabel, fontsize=12, fontweight='normal')
    ax.set_ylabel(ylabel, fontsize=12, fontweight='normal')
    
    if log_scale:
        ax.set_xscale('log', base=2)
        ax.set_xticks([1, 2, 4, 8, 16, 32, 64])
        ax.set_xticklabels(['1', '2', '4', '8', '16', '32', '64'])
    
    # Clean grid
    ax.grid(True, alpha=0.3, linestyle='-', linewidth=0.5)
    ax.set_facecolor('white')
    
    # Remove top and right spines for cleaner look
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#CCCCCC')
    ax.spines['bottom'].set_color('#CCCCCC')

def create_cpu_performance_plot(cpu_df, output_dir):
    """Create clear CPU performance plot."""
    print("📊 Creating CPU performance plot...")
    
    # Prepare data
    plot_data = []
    for _, row in cpu_df.iterrows():
        if pd.notna(row['Threads']) and pd.notna(row['Measured Throughput (Events per Second)']):
            env_name = row['Virtualization Type']
            if env_name == 'Virtual Machine':
                env_name = 'VM'  # Shorter name for clarity
            plot_data.append({
                'Environment': env_name,
                'Threads': int(row['Threads']),
                'Throughput': row['Measured Throughput (Events per Second)']
            })
    
    plot_df = pd.DataFrame(plot_data)
    
    # Create single focused plot
    fig, ax = plt.subplots(figsize=(12, 7))
    
    # Plot lines with clear differentiation
    for env in ['Baremetal', 'Container', 'VM']:
        env_data = plot_df[plot_df['Environment'] == env].sort_values('Threads')
        if not env_data.empty:
            ax.plot(env_data['Threads'], env_data['Throughput'], 
                   marker=MARKERS.get(env, 'o'), linewidth=3, markersize=8,
                   label=env, color=COLORS.get(env, 'gray'), 
                   markerfacecolor='white', markeredgewidth=2)
    
    setup_clean_plot(ax, 'CPU Performance Comparison', 
                    'Number of Threads', 'Throughput (Events/Second)', log_scale=True)
    
    # Position legend clearly
    ax.legend(frameon=True, fancybox=True, loc='upper left', 
             bbox_to_anchor=(0.02, 0.98), framealpha=0.9)
    
    # Ensure proper spacing and no overlapping
    plt.tight_layout(pad=2.0)
    plt.subplots_adjust(top=0.92, bottom=0.12, left=0.12, right=0.95)
    
    plt.savefig(output_dir / 'clear_cpu_performance.png', dpi=300, 
               bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close()
    print("✅ CPU performance plot saved")

def create_memory_performance_plot(memory_df, output_dir):
    """Create clear Memory performance plot."""
    print("📊 Creating Memory performance plot...")
    
    plot_data = []
    for _, row in memory_df.iterrows():
        if pd.notna(row['Threads']) and pd.notna(row['Throughput (MiB/sec)']):
            env_name = row['Virtualization Type']
            if env_name == 'Virtual Machine':
                env_name = 'VM'
            plot_data.append({
                'Environment': env_name,
                'Threads': int(row['Threads']),
                'Throughput': row['Throughput (MiB/sec)']
            })
    
    plot_df = pd.DataFrame(plot_data)
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    for env in ['Baremetal', 'Container', 'VM']:
        env_data = plot_df[plot_df['Environment'] == env].sort_values('Threads')
        if not env_data.empty:
            ax.plot(env_data['Threads'], env_data['Throughput'], 
                   marker=MARKERS.get(env, 'o'), linewidth=3, markersize=8,
                   label=env, color=COLORS.get(env, 'gray'),
                   markerfacecolor='white', markeredgewidth=2)
    
    setup_clean_plot(ax, 'Memory Performance Comparison', 
                    'Number of Threads', 'Throughput (MiB/sec)', log_scale=True)
    
    ax.legend(frameon=True, fancybox=True, loc='upper left',
             bbox_to_anchor=(0.02, 0.98), framealpha=0.9)
    
    plt.tight_layout(pad=2.0)
    plt.subplots_adjust(top=0.92, bottom=0.12, left=0.12, right=0.95)
    
    plt.savefig(output_dir / 'clear_memory_performance.png', dpi=300, 
               bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close()
    print("✅ Memory performance plot saved")

def create_network_performance_plot(network_df, output_dir):
    """Create clear Network performance plot."""
    print("📊 Creating Network performance plot...")
    
    plot_data = []
    for _, row in network_df.iterrows():
        if pd.notna(row['Client Threads']) and pd.notna(row['Measured Throughput (Gbits/s)']):
            env_name = row['Virtualization Type']
            if env_name == 'Virtual Machine':
                env_name = 'VM'
            plot_data.append({
                'Environment': env_name,
                'Threads': int(row['Client Threads']),
                'Bandwidth': row['Measured Throughput (Gbits/s)']
            })
    
    plot_df = pd.DataFrame(plot_data)
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    for env in ['Baremetal', 'Container', 'VM']:
        env_data = plot_df[plot_df['Environment'] == env].sort_values('Threads')
        if not env_data.empty:
            ax.plot(env_data['Threads'], env_data['Bandwidth'], 
                   marker=MARKERS.get(env, 'o'), linewidth=3, markersize=8,
                   label=env, color=COLORS.get(env, 'gray'),
                   markerfacecolor='white', markeredgewidth=2)
    
    setup_clean_plot(ax, 'Network Performance Comparison', 
                    'Number of Threads', 'Bandwidth (Gbits/sec)', log_scale=True)
    
    ax.legend(frameon=True, fancybox=True, loc='upper left',
             bbox_to_anchor=(0.02, 0.98), framealpha=0.9)
    
    plt.tight_layout(pad=2.0)
    plt.subplots_adjust(top=0.92, bottom=0.12, left=0.12, right=0.95)
    
    plt.savefig(output_dir / 'clear_network_performance.png', dpi=300, 
               bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close()
    print("✅ Network performance plot saved")

def create_disk_performance_plot(disk_df, output_dir):
    """Create clear Disk performance plot."""
    print("📊 Creating Disk performance plot...")
    
    plot_data = []
    for _, row in disk_df.iterrows():
        if pd.notna(row['Threads']) and pd.notna(row['Measured Throughput (MiB/s)']):
            env_name = row['Virtualization Type']
            if env_name == 'Virtual Machine':
                env_name = 'VM'
            plot_data.append({
                'Environment': env_name,
                'Threads': int(row['Threads']),
                'Throughput': row['Measured Throughput (MiB/s)']
            })
    
    plot_df = pd.DataFrame(plot_data)
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    for env in ['Baremetal', 'Container', 'VM']:
        env_data = plot_df[plot_df['Environment'] == env].sort_values('Threads')
        if not env_data.empty:
            ax.plot(env_data['Threads'], env_data['Throughput'], 
                   marker=MARKERS.get(env, 'o'), linewidth=3, markersize=8,
                   label=env, color=COLORS.get(env, 'gray'),
                   markerfacecolor='white', markeredgewidth=2)
    
    setup_clean_plot(ax, 'Disk Performance Comparison', 
                    'Number of Threads', 'Throughput (MiB/s)', log_scale=True)
    
    ax.legend(frameon=True, fancybox=True, loc='upper left',
             bbox_to_anchor=(0.02, 0.98), framealpha=0.9)
    
    plt.tight_layout(pad=2.0)
    plt.subplots_adjust(top=0.92, bottom=0.12, left=0.12, right=0.95)
    
    plt.savefig(output_dir / 'clear_disk_performance.png', dpi=300, 
               bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close()
    print("✅ Disk performance plot saved")

def create_efficiency_summary_plot(sheets, output_dir):
    """Create clear efficiency summary bar chart with no text overlap."""
    print("📊 Creating Enhanced Efficiency Summary plot...")
    
    # Calculate efficiency for each benchmark
    efficiency_data = []
    
    benchmarks = ['CPU', 'Memory', 'Network', 'Disk']
    
    for bench in benchmarks:
        if bench in sheets:
            df = sheets[bench]
            
            # Get maximum performance for baremetal and other environments
            max_perf = {}
            for _, row in df.iterrows():
                env = row['Virtualization Type']
                
                # Get thread count based on benchmark type
                if bench == 'Network':
                    threads = row['Client Threads'] if 'Client Threads' in row else 1
                else:
                    threads = row['Threads'] if 'Threads' in row else 1
                
                # Get performance metric
                if bench == 'CPU':
                    perf = row['Measured Throughput (Events per Second)']
                elif bench == 'Memory':
                    perf = row['Throughput (MiB/sec)']
                elif bench == 'Network':
                    perf = row['Measured Throughput (Gbits/s)']
                elif bench == 'Disk':
                    perf = row['Measured Throughput (MiB/s)']
                
                if pd.notna(perf) and threads == 64:  # Use 64-thread results
                    if env not in max_perf or perf > max_perf[env]:
                        max_perf[env] = perf
            
            # Calculate efficiency relative to baremetal
            if 'Baremetal' in max_perf:
                baremetal_perf = max_perf['Baremetal']
                for env in ['Container', 'Virtual Machine']:
                    if env in max_perf:
                        efficiency = (max_perf[env] / baremetal_perf) * 100
                        env_name = 'VM' if env == 'Virtual Machine' else env
                        efficiency_data.append({
                            'Benchmark': bench,
                            'Environment': env_name,
                            'Efficiency': efficiency
                        })
    
    if not efficiency_data:
        print("❌ No efficiency data found")
        return
    
    efficiency_df = pd.DataFrame(efficiency_data)
    
    # Create enhanced bar chart with better spacing
    fig, ax = plt.subplots(figsize=(14, 8))
    
    # Prepare data for grouped bar chart
    benchmarks = efficiency_df['Benchmark'].unique()
    environments = ['Container', 'VM']
    
    x = np.arange(len(benchmarks))
    width = 0.30  # Slightly narrower bars for better spacing
    
    # Calculate max efficiency for proper y-axis scaling
    all_values = []
    env_data_dict = {}
    
    for i, env in enumerate(environments):
        env_data = []
        for bench in benchmarks:
            eff_val = efficiency_df[(efficiency_df['Benchmark'] == bench) & 
                                  (efficiency_df['Environment'] == env)]['Efficiency']
            value = eff_val.iloc[0] if len(eff_val) > 0 else 0
            env_data.append(value)
            all_values.append(value)
        env_data_dict[env] = env_data
    
    max_value = max(all_values) if all_values else 100
    
    # Set y-axis limits with adequate space for labels
    y_limit = max(120, max_value * 1.25)  # Ensure at least 20% space above highest bar
    ax.set_ylim(0, y_limit)
    
    # Create bars with enhanced styling
    for i, env in enumerate(environments):
        env_data = env_data_dict[env]
        bars = ax.bar(x + i * width, env_data, width, 
                     label=env, color=COLORS.get(env, 'gray'), 
                     alpha=0.85, edgecolor='white', linewidth=1.5)
        
        # Add value labels on bars with smart positioning
        for j, bar in enumerate(bars):
            height = bar.get_height()
            # Position labels inside bars if they're tall enough, outside if short
            if height > 15:
                label_y = height - 8
                label_color = 'white'
                fontweight = 'bold'
            else:
                label_y = height + 3
                label_color = 'black'
                fontweight = 'normal'
                
            ax.text(bar.get_x() + bar.get_width()/2., label_y,
                   f'{height:.1f}%', ha='center', va='center' if height > 15 else 'bottom',
                   fontsize=10, color=label_color, fontweight=fontweight)
    
    # Enhanced title and labels with better spacing
    ax.set_title('Virtualization Efficiency Comparison\n(Relative to Baremetal Performance)', 
                fontsize=16, fontweight='bold', pad=25)
    ax.set_xlabel('Benchmark Type', fontsize=13, fontweight='semibold', labelpad=10)
    ax.set_ylabel('Efficiency (% of Baremetal)', fontsize=13, fontweight='semibold', labelpad=10)
    
    # Position x-axis labels properly
    ax.set_xticks(x + width / 2)
    ax.set_xticklabels(benchmarks, fontsize=12)
    
    # Add 100% reference line with clear positioning
    ax.axhline(y=100, color='#d62728', linestyle='--', alpha=0.8, linewidth=2)
    ax.text(0.02, 103, 'Baremetal Baseline (100%)', 
           transform=ax.get_yaxis_transform(), ha='left', va='bottom',
           color='#d62728', fontsize=11, fontweight='semibold',
           bbox=dict(boxstyle="round,pad=0.3", facecolor='white', alpha=0.8))
    
    # Enhanced legend positioning
    ax.legend(frameon=True, fancybox=True, loc='upper left', 
             bbox_to_anchor=(0.02, 0.98), fontsize=12,
             framealpha=0.95, edgecolor='gray')
    
    # Clean grid and styling
    ax.grid(True, alpha=0.3, axis='y', linestyle='-', linewidth=0.5)
    ax.set_axisbelow(True)
    
    # Clean spines with subtle color
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#CCCCCC')
    ax.spines['bottom'].set_color('#CCCCCC')
    
    # Enhanced layout with generous padding
    plt.tight_layout(pad=3.0)
    plt.subplots_adjust(top=0.88, bottom=0.15, left=0.12, right=0.96)
    
    # Save with high quality
    plt.savefig(output_dir / 'clear_efficiency_summary.png', dpi=300, 
               bbox_inches='tight', facecolor='white', edgecolor='none',
               pad_inches=0.2)
    plt.close()
    print("✅ Enhanced Efficiency summary plot saved")

def main():
    """Main plotting function."""
    # Input and output paths
    excel_file = Path('Final_Analysis.xlsx')
    output_dir = Path('plots')
    output_dir.mkdir(exist_ok=True)
    
    print("🎨 CS553 HW#2 Clear Plot Generator")
    print("=" * 50)
    
    # Load data
    sheets = load_data_from_excel(excel_file)
    if not sheets:
        return
    
    # Generate individual performance plots
    if 'CPU' in sheets:
        create_cpu_performance_plot(sheets['CPU'], output_dir)
    
    if 'Memory' in sheets:
        create_memory_performance_plot(sheets['Memory'], output_dir)
    
    if 'Network' in sheets:
        create_network_performance_plot(sheets['Network'], output_dir)
    
    if 'Disk' in sheets:
        create_disk_performance_plot(sheets['Disk'], output_dir)
    
    # Generate efficiency summary
    create_efficiency_summary_plot(sheets, output_dir)
    
    print("\n🎉 All clear plots generated successfully!")
    print(f"📁 Output directory: {output_dir.absolute()}")
    
    # List generated files
    plot_files = list(output_dir.glob('*.png'))
    print(f"📊 Generated {len(plot_files)} plots:")
    for file in sorted(plot_files):
        print(f"   • {file.name}")

if __name__ == "__main__":
    main()