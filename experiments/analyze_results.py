#!/usr/bin/env python3
"""Summarize static candidate paths, not final vulnerability verdicts."""

import argparse
import pandas as pd
import re
from pathlib import Path
from collections import Counter

def extract_summary_info(result_text):
    sources_match = re.search(r"Found (\d+) taint sources", result_text)
    sinks_match = re.search(r"Found (\d+) taint sinks", result_text)
    paths_match = re.search(r"Found (\d+) tainted paths", result_text)
    
    sources_count = int(sources_match.group(1)) if sources_match else 0
    sinks_count = int(sinks_match.group(1)) if sinks_match else 0
    paths_count = int(paths_match.group(1)) if paths_match else 0
    
    source_types = []
    for match in re.finditer(r"Source #\d+: (\w+)", result_text):
        source_types.append(match.group(1))
    
    sink_types = []
    for match in re.finditer(r"Sink #\d+: (\w+)", result_text):
        sink_types.append(match.group(1))
    
    return {
        "sources_count": sources_count,
        "sinks_count": sinks_count,
        "paths_count": paths_count,
        "source_types": source_types,
        "sink_types": sink_types,
        "has_taint_paths": paths_count > 0
    }

def main(dataset_path, results_dir="pmdetector/analysis_results",
         output_path="build/static_path_summary.csv"):
    df = pd.read_excel(dataset_path)
    
    contract_info = {}
    for _, row in df.iterrows():
        protocol = row["Protocol"]
        address = row["Contract Address"]
        platform = row["Platform"].lower()
        label = row["Label"]
        
        contract_hash = __import__('hashlib').md5(f"{protocol}_{address}_{platform}".encode()).hexdigest()[:8]
        contract_info[contract_hash] = {
            "protocol": protocol,
            "address": address,
            "platform": platform,
            "label": label
        }
    
    results_dir = Path(results_dir)
    if not results_dir.is_dir():
        raise FileNotFoundError(f"Static results directory does not exist: {results_dir}")
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    all_results = []
    
    for result_file in sorted(results_dir.glob("*.txt")):
        filename = result_file.name
        contract_hash = filename.split("_")[0]
        
        if contract_hash not in contract_info:
            print(f"Warning: Could not find contract info for {filename}")
            continue
        
        with open(result_file, "r") as f:
            result_text = f.read()

        if not re.search(r"Found \d+ tainted paths", result_text):
            print(f"Warning: Skipping {filename}: no completed static path summary.")
            continue
        
        summary = extract_summary_info(result_text)
        
        result_data = {
            **contract_info[contract_hash],
            **summary,
            "filename": filename
        }
        
        all_results.append(result_data)
    
    columns = ["protocol", "address", "platform", "label", "sources_count",
               "sinks_count", "paths_count", "source_types", "sink_types",
               "has_taint_paths", "filename"]
    results_df = pd.DataFrame(all_results, columns=columns)
    
    if results_df.empty:
        print("\n=== PMDetector Static Path Summary ===")
        print("No analysis result files found to summarize.")
        results_df.to_csv(output_path, index=False)
        print(f"\nAn empty summary (with headers) has been written to: {output_path}")
        return

    print("\n=== PMDetector Static Path Summary ===")
    print("Candidate paths only; this is not a count of confirmed vulnerabilities or paper metrics.")
    print(f"Total contracts analyzed: {len(results_df)}")
    print(f"Contracts with candidate taint paths: {results_df['has_taint_paths'].sum()} ({results_df['has_taint_paths'].mean():.1%})")
    print(f"Total taint sources found: {results_df['sources_count'].sum()}")
    print(f"Total taint sinks found: {results_df['sinks_count'].sum()}")
    print(f"Total tainted paths found: {results_df['paths_count'].sum()}")
    
    print("\n=== Results by Platform ===")
    platform_stats = results_df.groupby("platform").agg({
        "has_taint_paths": ["count", "sum", "mean"],
        "sources_count": "sum",
        "sinks_count": "sum",
        "paths_count": "sum"
    })
    print(platform_stats)
    
    print("\n=== Results by Label ===")
    label_stats = results_df.groupby("label").agg({
        "has_taint_paths": ["count", "sum", "mean"],
        "sources_count": "sum",
        "sinks_count": "sum",
        "paths_count": "sum"
    })
    print(label_stats)

    all_source_types = []
    for source_types in results_df["source_types"]:
        all_source_types.extend(source_types)
    
    print("\n=== Source Types ===")
    source_type_counts = Counter(all_source_types)
    for source_type, count in source_type_counts.most_common():
        print(f"{source_type}: {count}")
    
    all_sink_types = []
    for sink_types in results_df["sink_types"]:
        all_sink_types.extend(sink_types)
    
    print("\n=== Sink Types ===")
    sink_type_counts = Counter(all_sink_types)
    for sink_type, count in sink_type_counts.most_common():
        print(f"{sink_type}: {count}")
    
    results_df.to_csv(output_path, index=False)
    print(f"\nDetailed static summary saved to {output_path}")


def cli():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", required=True, help="Path to the labeled XLSX dataset")
    parser.add_argument("--results-dir", default="pmdetector/analysis_results",
                        help="Directory of static text reports")
    parser.add_argument("--output", default="build/static_path_summary.csv",
                        help="Destination CSV; defaults to a new file, not the historical summary")
    args = parser.parse_args()
    main(args.dataset, args.results_dir, args.output)

if __name__ == "__main__":
    cli()
