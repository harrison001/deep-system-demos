#!/bin/bash

# Performance benchmark script for kprobe vs fentry eBPF programs
# This script measures the overhead of different eBPF attachment methods

set -e

# Paths to your executables
KPROBE_BIN="../target/release/sentinel_loader"
FENTRY_BIN="../target/release/sentinel_fentry_loader"
ROUNDS=3
TEST_DURATION=15   # seconds
WORKLOAD_DURATION=10   # seconds for generating file operations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if required tools are available
check_requirements() {
    if ! command -v perf &> /dev/null; then
        echo -e "${RED}Error: perf not found. Please install linux-perf package.${NC}"
        exit 1
    fi
    
    if ! command -v stress-ng &> /dev/null; then
        echo -e "${YELLOW}Warning: stress-ng not found. Will use basic file operations for load generation.${NC}"
        USE_STRESS=false
    else
        USE_STRESS=true
    fi
}

# Generate file system load to trigger eBPF programs
generate_load() {
    local duration=$1
    echo -e "${BLUE}[*] Generating filesystem load for ${duration}s...${NC}"
    
    if $USE_STRESS; then
        timeout $duration stress-ng --hdd 2 --hdd-ops 1000 --temp-path /tmp >/dev/null 2>&1 &
    else
        # Fallback: simple file operations
        {
            for i in $(seq 1 100); do
                for j in $(seq 1 10); do
                    echo "test data $i $j" > "/tmp/benchmark_test_${i}_${j}.tmp"
                    cat "/tmp/benchmark_test_${i}_${j}.tmp" > /dev/null
                    rm -f "/tmp/benchmark_test_${i}_${j}.tmp"
                    sleep 0.01
                done
            done
        } &
    fi
    
    LOAD_PID=$!
}

# Clean up function
cleanup() {
    echo -e "\n${YELLOW}[*] Cleaning up...${NC}"
    # Kill any running processes
    pkill -f sentinel_loader || true
    pkill -f sentinel_fentry_loader || true
    pkill -f stress-ng || true
    rm -f /tmp/benchmark_test_*.tmp || true
    
    if [ -n "$LOAD_PID" ]; then
        kill $LOAD_PID 2>/dev/null || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Output CSV headers
echo "type,round,cycles,instructions,cache_misses,page_faults,context_switches,cpu_migrations,elapsed_time" > perf_results.csv

run_test() {
    local bin="$1"
    local label="$2"
    
    echo -e "${GREEN}[*] Testing $label version...${NC}"
    
    for i in $(seq 1 $ROUNDS); do
        echo -e "${BLUE}[*] Running $label - Round $i/$ROUNDS...${NC}"
        
        # Start the eBPF program in background
        $bin &
        local ebpf_pid=$!
        
        # Give it time to attach
        sleep 2
        
        # Generate load and measure performance
        generate_load $WORKLOAD_DURATION
        
        # Run perf stat on the load generation process
        perf stat -e cycles,instructions,cache-misses,page-faults,context-switches,cpu-migrations \
                  -x, -p $LOAD_PID \
                  sleep $WORKLOAD_DURATION 2> /tmp/perf_output.txt || true
        
        # Stop the eBPF program
        kill $ebpf_pid 2>/dev/null || true
        wait $ebpf_pid 2>/dev/null || true
        
        # Wait for load generation to finish
        wait $LOAD_PID 2>/dev/null || true
        
        # Parse perf output
        if [ -f /tmp/perf_output.txt ]; then
            # Parse CSV format from perf stat
            cycles=$(grep "cycles" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            instrs=$(grep "instructions" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            cache_misses=$(grep "cache-misses" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            page_faults=$(grep "page-faults" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            ctx_switches=$(grep "context-switches" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            cpu_migrations=$(grep "cpu-migrations" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            elapsed=$(grep "seconds time elapsed" /tmp/perf_output.txt | cut -d',' -f1 | tr -d ' ' || echo "0")
            
            # Clean up parsed values (remove any non-numeric characters except decimal points)
            cycles=$(echo "$cycles" | sed 's/[^0-9.]//g')
            instrs=$(echo "$instrs" | sed 's/[^0-9.]//g')
            cache_misses=$(echo "$cache_misses" | sed 's/[^0-9.]//g')
            page_faults=$(echo "$page_faults" | sed 's/[^0-9.]//g')
            ctx_switches=$(echo "$ctx_switches" | sed 's/[^0-9.]//g')
            cpu_migrations=$(echo "$cpu_migrations" | sed 's/[^0-9.]//g')
            elapsed=$(echo "$elapsed" | sed 's/[^0-9.]//g')
            
            # Set default values if parsing failed
            [ -z "$cycles" ] && cycles="0"
            [ -z "$instrs" ] && instrs="0"
            [ -z "$cache_misses" ] && cache_misses="0"
            [ -z "$page_faults" ] && page_faults="0"
            [ -z "$ctx_switches" ] && ctx_switches="0"
            [ -z "$cpu_migrations" ] && cpu_migrations="0"
            [ -z "$elapsed" ] && elapsed="0"
            
            echo "$label,$i,$cycles,$instrs,$cache_misses,$page_faults,$ctx_switches,$cpu_migrations,$elapsed" >> perf_results.csv
            
            echo -e "${YELLOW}    Cycles: $cycles, Instructions: $instrs, Cache misses: $cache_misses${NC}"
        else
            echo -e "${RED}    Failed to collect perf data for round $i${NC}"
            echo "$label,$i,0,0,0,0,0,0,0" >> perf_results.csv
        fi
        
        # Clean up temp files
        rm -f /tmp/perf_output.txt
        
        # Wait between rounds
        sleep 2
    done
}

# Create analysis script
create_analysis_script() {
    cat > analyze_results.py << 'EOF'
#!/usr/bin/env python3
import csv
import statistics
import sys

def safe_float(value):
    """Safely convert value to float, return 0.0 if conversion fails"""
    try:
        return float(value) if value and value != '' else 0.0
    except (ValueError, TypeError):
        return 0.0

def analyze_results():
    # Read the CSV file
    try:
        with open('perf_results.csv', 'r') as f:
            reader = csv.DictReader(f)
            data = list(reader)
    except FileNotFoundError:
        print("Error: perf_results.csv not found")
        return
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return
    
    if not data:
        print("Error: No data found in CSV file")
        return
    
    # Separate data by type
    kprobe_data = [row for row in data if row['type'] == 'kprobe']
    fentry_data = [row for row in data if row['type'] == 'fentry']
    
    if not kprobe_data or not fentry_data:
        print("Error: Missing data for kprobe or fentry")
        return
    
    # Metrics to analyze
    metrics = ['cycles', 'instructions', 'cache_misses', 'page_faults', 
               'context_switches', 'cpu_migrations', 'elapsed_time']
    
    print("=== eBPF Performance Comparison: kprobe vs fentry ===\n")
    
    # Calculate statistics for each metric
    results = {}
    
    for metric in metrics:
        # Extract values and convert to float
        kprobe_values = [safe_float(row[metric]) for row in kprobe_data]
        fentry_values = [safe_float(row[metric]) for row in fentry_data]
        
        # Filter out zero values for meaningful statistics
        kprobe_nonzero = [v for v in kprobe_values if v > 0]
        fentry_nonzero = [v for v in fentry_values if v > 0]
        
        if not kprobe_nonzero and not fentry_nonzero:
            continue
            
        # Calculate statistics
        def calc_stats(values):
            if not values:
                return {'mean': 0, 'std': 0, 'min': 0, 'max': 0}
            return {
                'mean': statistics.mean(values),
                'std': statistics.stdev(values) if len(values) > 1 else 0,
                'min': min(values),
                'max': max(values)
            }
        
        kprobe_stats = calc_stats(kprobe_nonzero if kprobe_nonzero else kprobe_values)
        fentry_stats = calc_stats(fentry_nonzero if fentry_nonzero else fentry_values)
        
        results[metric] = {
            'kprobe': kprobe_stats,
            'fentry': fentry_stats
        }
        
        # Display results
        print(f"--- {metric.upper().replace('_', ' ')} ---")
        print(f"  kprobe: {kprobe_stats['mean']:,.0f} ± {kprobe_stats['std']:,.0f}")
        print(f"  fentry: {fentry_stats['mean']:,.0f} ± {fentry_stats['std']:,.0f}")
        
        # Calculate improvement percentage
        if kprobe_stats['mean'] > 0:
            improvement = ((kprobe_stats['mean'] - fentry_stats['mean']) / kprobe_stats['mean']) * 100
            print(f"  Improvement: {improvement:+.2f}%")
        else:
            print("  Improvement: N/A (no baseline)")
        print()
    
    # Overall summary
    print("=== SUMMARY ===")
    
    if 'cycles' in results and results['cycles']['kprobe']['mean'] > 0:
        cycle_improvement = ((results['cycles']['kprobe']['mean'] - 
                             results['cycles']['fentry']['mean']) / 
                            results['cycles']['kprobe']['mean']) * 100
        print(f"fentry shows {cycle_improvement:+.2f}% cycle count difference vs kprobe")
    
    if 'context_switches' in results and results['context_switches']['kprobe']['mean'] > 0:
        ctx_improvement = ((results['context_switches']['kprobe']['mean'] - 
                           results['context_switches']['fentry']['mean']) / 
                          results['context_switches']['kprobe']['mean']) * 100
        print(f"fentry shows {ctx_improvement:+.2f}% context switch difference vs kprobe")
    
    # Performance recommendation
    print("\n=== PERFORMANCE INSIGHTS ===")
    better_metrics = 0
    total_metrics = 0
    
    for metric in ['cycles', 'instructions', 'context_switches']:
        if metric in results:
            kprobe_mean = results[metric]['kprobe']['mean']
            fentry_mean = results[metric]['fentry']['mean']
            if kprobe_mean > 0:
                total_metrics += 1
                if fentry_mean < kprobe_mean:
                    better_metrics += 1
    
    if total_metrics > 0:
        improvement_ratio = better_metrics / total_metrics
        if improvement_ratio >= 0.6:
            print("✅ fentry shows better performance in most metrics")
        elif improvement_ratio >= 0.4:
            print("⚖️  Performance is mixed between kprobe and fentry")
        else:
            print("⚠️  kprobe shows better performance in most metrics")
    
    print(f"\nNote: Analysis based on {len(kprobe_data)} kprobe and {len(fentry_data)} fentry measurements")

if __name__ == "__main__":
    analyze_results()
EOF
    chmod +x analyze_results.py
}

# Main execution
echo -e "${GREEN}=== eBPF Performance Benchmark: kprobe vs fentry ===${NC}"
echo -e "${BLUE}Rounds: $ROUNDS, Test duration: ${TEST_DURATION}s each${NC}"

check_requirements
create_analysis_script

# Run tests
run_test "$KPROBE_BIN" "kprobe"
run_test "$FENTRY_BIN" "fentry"

echo -e "${GREEN}[+] Benchmark completed! Results saved to: perf_results.csv${NC}"
echo -e "${YELLOW}[*] Run './analyze_results.py' to see detailed analysis${NC}"

# Auto-run analysis if Python is available
if command -v python3 &> /dev/null; then
    echo -e "${BLUE}[*] Running automatic analysis...${NC}"
    python3 analyze_results.py
fi
