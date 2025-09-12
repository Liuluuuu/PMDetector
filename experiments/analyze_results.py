#!/usr/bin/env python3
import os
import pandas as pd
import json
import re
from pathlib import Path
from collections import Counter, defaultdict

def extract_summary_info(result_text):
    # Extract counts using regex
    sources_match = re.search(r"Found (\d+) taint sources", result_text)
    sinks_match = re.search(r"Found (\d+) taint sinks", result_text)
    paths_match = re.search(r"Found (\d+) tainted paths", result_text)
    
    sources_count = int(sources_match.group(1)) if sources_match else 0
    sinks_count = int(sinks_match.group(1)) if sinks_match else 0
    paths_count = int(paths_match.group(1)) if paths_match else 0
    
    # Extract source types
    source_types = []
    for match in re.finditer(r"Source #\d+: (\w+)", result_text):
        source_types.append(match.group(1))
    
    # Extract sink types
    sink_types = []
    for match in re.finditer(r"Sink #\d+: (\w+)", result_text):
        sink_types.append(match.group(1))
    
    return {
        "sources_count": sources_count,
        "sinks_count": sinks_count,
        "paths_count": paths_count,
        "source_types": source_types,
        "sink_types": sink_types,
        "has_vulnerability": paths_count > 0
    }

def main(dataset_path):
    df = pd.read_excel(dataset_path)
    
    contract_info = {}
    for _, row in df.iterrows():
        protocol = row["Protocol"]
        address = row["Contract Address"]
        platform = row["Platform"].lower()
        label = row["Label"]
        
        # Create the same hash as in process_dataset.py
        contract_hash = __import__('hashlib').md5(f"{protocol}_{address}_{platform}".encode()).hexdigest()[:8]
        contract_info[contract_hash] = {
            "protocol": protocol,
            "address": address,
            "platform": platform,
            "label": label
        }
    
    results_dir = Path("/Users/crystal/PycharmProjects/PMDetector/experiments/pmdetector/analysis_results")
    all_results = []
    
    for result_file in results_dir.glob("*.txt"):
        filename = result_file.name
        contract_hash = filename.split("_")[0]
        
        if contract_hash not in contract_info:
            print(f"Warning: Could not find contract info for {filename}")
            continue
        
        with open(result_file, "r") as f:
            result_text = f.read()
        
        summary = extract_summary_info(result_text)
        
        result_data = {
            **contract_info[contract_hash],
            **summary,
            "filename": filename
        }
        
        all_results.append(result_data)
    
    results_df = pd.DataFrame(all_results)
    
    if results_df.empty:
        print("\n=== PMDetector Analysis Results ===")
        print("No analysis result files found to summarize.")
        # Create an empty summary file so downstream steps don't fail
        Path("/Users/crystal/PycharmProjects/PMDetector/experiments/pmdetector/analysis_summary.csv").touch()
        print("\nAn empty summary file has been created at: pmdetector/analysis_summary.csv")
        return # Exit the function gracefully

    print("\n=== PMDetector Analysis Results ===")
    print(f"Total contracts analyzed: {len(results_df)}")
    print(f"Contracts with vulnerabilities: {results_df['has_vulnerability'].sum()} ({results_df['has_vulnerability'].mean():.1%})")
    print(f"Total taint sources found: {results_df['sources_count'].sum()}")
    print(f"Total taint sinks found: {results_df['sinks_count'].sum()}")
    print(f"Total tainted paths found: {results_df['paths_count'].sum()}")
    
    # Analysis by platform
    print("\n=== Results by Platform ===")
    platform_stats = results_df.groupby("platform").agg({
        "has_vulnerability": ["count", "sum", "mean"],
        "sources_count": "sum",
        "sinks_count": "sum",
        "paths_count": "sum"
    })
    print(platform_stats)
    
    # Analysis by label
    print("\n=== Results by Label ===")
    label_stats = results_df.groupby("label").agg({
        "has_vulnerability": ["count", "sum", "mean"],
        "sources_count": "sum",
        "sinks_count": "sum",
        "paths_count": "sum"
    })
    print(label_stats)
    
    # Analyze source types
    all_source_types = []
    for source_types in results_df["source_types"]:
        all_source_types.extend(source_types)
    
    print("\n=== Source Types ===")
    source_type_counts = Counter(all_source_types)
    for source_type, count in source_type_counts.most_common():
        print(f"{source_type}: {count}")
    
    # Analyze sink types
    all_sink_types = []
    for sink_types in results_df["sink_types"]:
        all_sink_types.extend(sink_types)
    
    print("\n=== Sink Types ===")
    sink_type_counts = Counter(all_sink_types)
    for sink_type, count in sink_type_counts.most_common():
        print(f"{sink_type}: {count}")
    
    # Save detailed results to CSV
    results_df.to_csv("/Users/crystal/PycharmProjects/PMDetector/experiments/pmdetector/analysis_summary.csv", index=False)
    print("\nDetailed results saved to pmdetector/analysis_summary.csv")

if __name__ == "__main__":
    main()
