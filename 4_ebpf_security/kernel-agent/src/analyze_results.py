#!/usr/bin/env python3
import pandas as pd
import numpy as np

def analyze_results():
    # Read the CSV file
    try:
        df = pd.read_csv('perf_results.csv')
    except FileNotFoundError:
        print("Error: perf_results.csv not found")
        return
    
    # Convert numeric columns
    numeric_cols = ['cycles', 'instructions', 'cache_misses', 'page_faults', 
                    'context_switches', 'cpu_migrations', 'elapsed_time']
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
    
    # Group by type and calculate statistics
    stats = df.groupby('type')[numeric_cols].agg(['mean', 'std', 'min', 'max'])
    
    print("=== eBPF Performance Comparison: kprobe vs fentry ===\n")
    
    for metric in numeric_cols:
        print(f"--- {metric.upper().replace('_', ' ')} ---")
        kprobe_mean = stats.loc['kprobe', (metric, 'mean')]
        fentry_mean = stats.loc['fentry', (metric, 'mean')]
        
        if kprobe_mean > 0:
            improvement = ((kprobe_mean - fentry_mean) / kprobe_mean) * 100
            print(f"  kprobe: {kprobe_mean:,.0f} ± {stats.loc['kprobe', (metric, 'std')]:,.0f}")
            print(f"  fentry: {fentry_mean:,.0f} ± {stats.loc['fentry', (metric, 'std')]:,.0f}")
            print(f"  Improvement: {improvement:+.2f}%")
        else:
            print(f"  kprobe: {kprobe_mean:,.0f}")
            print(f"  fentry: {fentry_mean:,.0f}")
        print()
    
    # Overall summary
    print("=== SUMMARY ===")
    if stats.loc['kprobe', ('cycles', 'mean')] > 0:
        cycle_improvement = ((stats.loc['kprobe', ('cycles', 'mean')] - 
                             stats.loc['fentry', ('cycles', 'mean')]) / 
                            stats.loc['kprobe', ('cycles', 'mean')]) * 100
        print(f"fentry shows {cycle_improvement:+.2f}% cycle count difference vs kprobe")
    
    if stats.loc['kprobe', ('context_switches', 'mean')] > 0:
        ctx_improvement = ((stats.loc['kprobe', ('context_switches', 'mean')] - 
                           stats.loc['fentry', ('context_switches', 'mean')]) / 
                          stats.loc['kprobe', ('context_switches', 'mean')]) * 100
        print(f"fentry shows {ctx_improvement:+.2f}% context switch difference vs kprobe")

if __name__ == "__main__":
    analyze_results()
