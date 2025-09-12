#!/usr/bin/env python3
import os
import sys
import argparse
import json
import time
import concurrent.futures
from pathlib import Path

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pmdetector.llm.multi_agents import MultiAgentAnalyzer
from pmdetector.core.sanity_checker import SanityChecker

def run_taint_analysis_only_baseline(model, limit=None):
    print(f"\n=== Running PMDetector-NoLLM baseline with model: {model} ===")
    start_time = time.time()
    
    results_dir = Path("pmdetector/analysis_results")
    flattened_dir = Path("pmdetector/flattened_contracts")
    
    result_files = list(results_dir.glob("*.txt"))
    
    if limit is not None:
        print(f"Limiting analysis to {limit} contracts (out of {len(result_files)} total)")
        result_files = result_files[:limit]

    valid_result_files = []
    for result_file in result_files:
        contract_id = result_file.stem
        source_file = flattened_dir / contract_id / "flattened.sol"
        if source_file.exists() and source_file.stat().st_size > 0:
            valid_result_files.append(result_file)
        else:
            print(f"Skipping {contract_id}: No valid source file found")
    
    print(f"Found {len(valid_result_files)} valid contracts out of {len(result_files)} total")
    
    checker = SanityChecker()
    
    results = {}
    
    for result_file in valid_result_files:
        contract_id = result_file.stem
        source_file = flattened_dir / contract_id / "flattened.sol"
        
        try:
            with open(result_file, 'r') as f:
                taint_content = f.read().strip()
            
            has_taint_paths = bool(taint_content and 
                                 taint_content != "No taint paths found." and
                                 "No taint paths found" not in taint_content and
                                 len(taint_content.strip()) > 0)
            
            if not has_taint_paths:
                results[contract_id] = {
                    "is_vulnerable": False,
                    "confidence": 1.0,
                    "explanation": "No taint paths found by static analysis",
                    "vulnerable_paths": [],
                    "vulnerable_groups": [],
                    "taint_analysis_result": "No paths found"
                }
                continue
            
            temp_result = {
                contract_id: {
                    "is_vulnerable": True,
                    "confidence": 1.0,
                    "explanation": "Taint paths found by static analysis",
                    "vulnerable_paths": [taint_content],
                    "vulnerable_groups": []
                }
            }
            
            try:
                filtered_result = checker.check_vulnerabilities(str(source_file), temp_result)
                contract_result = filtered_result[contract_id]
                
                # Determine final vulnerability based on sanity checker result
                if contract_result.get("filter_status") == "Verified True Positive":
                    is_vulnerable = True
                    explanation = "Taint paths found and verified by sanity checker"
                elif contract_result.get("filter_status") == "Filtered False Positive":
                    is_vulnerable = False
                    explanation = "Taint paths found but filtered out by sanity checker"
                else:
                    # If no filter_status, use original vulnerability status
                    is_vulnerable = contract_result.get("is_vulnerable", True)
                    explanation = contract_result.get("explanation", "Taint paths found by static analysis")
                
                results[contract_id] = {
                    "is_vulnerable": is_vulnerable,
                    "confidence": 1.0,
                    "explanation": explanation,
                    "vulnerable_paths": contract_result.get("vulnerable_paths", [taint_content]),
                    "vulnerable_groups": contract_result.get("vulnerable_groups", []),
                    "taint_analysis_result": "Paths found",
                    "filter_status": contract_result.get("filter_status", "No filtering applied")
                }
                
            except Exception as e:
                print(f"Error applying sanity check to {contract_id}: {e}")
                # If sanity checker fails, use taint analysis result
                results[contract_id] = {
                    "is_vulnerable": True,
                    "confidence": 1.0,
                    "explanation": f"Taint paths found by static analysis (sanity check failed: {str(e)})",
                    "vulnerable_paths": [taint_content],
                    "vulnerable_groups": [],
                    "taint_analysis_result": "Paths found",
                    "filter_status": "Sanity check failed"
                }
                
        except Exception as e:
            print(f"Error processing {contract_id}: {e}")
            results[contract_id] = {
                "is_vulnerable": False,
                "confidence": 0.0,
                "explanation": f"Error during analysis: {str(e)}",
                "vulnerable_paths": [],
                "vulnerable_groups": [],
                "taint_analysis_result": "Error",
                "filter_status": "Error"
            }

    return results


def patched_analyze_all_contracts_with_paths(self, limit=None):
    results_dir = Path("pmdetector/analysis_results")
    flattened_dir = Path("pmdetector/flattened_contracts")
    
    result_files = list(results_dir.glob("*.txt"))

    if limit is not None:
        print(f"Limiting analysis to {limit} contracts (out of {len(result_files)} total)")
        result_files = result_files[:limit]

    valid_result_files = []
    for result_file in result_files:
        contract_id = result_file.stem
        source_file = flattened_dir / contract_id / "flattened.sol"
        if source_file.exists() and source_file.stat().st_size > 0:
            valid_result_files.append(result_file)
        else:
            print(f"Skipping {contract_id}: No valid source file found")
    
    print(f"Found {len(valid_result_files)} valid contracts out of {len(result_files)} total")
    
    attack_model_path = Path("pmdetector/llm/price_manipulation_attack_model.txt")
    with open(attack_model_path, "r") as f:
        attack_model = f.read().strip()
    
    max_workers = 3 
    
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_contract = {
            executor.submit(self._analyze_single_contract, result_file, flattened_dir, attack_model): result_file
            for result_file in valid_result_files
        }
        
        for future in concurrent.futures.as_completed(future_to_contract):
            result_file = future_to_contract[future]
            try:
                contract_id, result = future.result()
                results[contract_id] = result
                time.sleep(0.5)
            except Exception as e:
                contract_id = result_file.stem
                print(f"Error analyzing {contract_id}: {str(e)}")
                results[contract_id] = {
                    "is_vulnerable": False,
                    "confidence": 0.0,
                    "explanation": f"Error during analysis: {str(e)}",
                    "vulnerable_paths": [],
                    "vulnerable_groups": []
                }
    
    return results

MultiAgentAnalyzer.analyze_all_contracts = patched_analyze_all_contracts_with_paths

def run_model_approach(model, approach, limit=None):
    print(f"\n=== Running {approach} analysis with model: {model} ===")
    start_time = time.time()
    
    try:
        analyzer = MultiAgentAnalyzer(model=model)

        try:
            llm_results = analyzer.analyze_all_contracts(limit=limit)
        except Exception as e:
            print(f"Error during analysis: {str(e)}")
            llm_results = {} 
    except Exception as e:
        print(f"Error initializing analyzer for {approach} with {model}: {str(e)}")
        llm_results = {} 
    
    model_results_json_path = Path(f"pmdetector/llm_results_{approach}_{model.replace('-', '_')}.json")
 
    elapsed_time = time.time() - start_time
    print(f"{approach.capitalize()} analysis with {model} completed in {elapsed_time:.2f} seconds")
    
    return llm_results

def main():
    parser = argparse.ArgumentParser(description="Run PMDetector for identifying price manipulation vulnerabilities.")
    parser.add_argument("--skip-processing", action="store_true", help="Skip processing contracts and only analyze results")
    parser.add_argument("--limit", type=int, default=None, help="Limit the number of contracts to process")
    args = parser.parse_args()
    
    flattened_dir = Path("pmdetector/flattened_contracts")
    results_dir = Path("pmdetector/analysis_results")
    flattened_dir.mkdir(exist_ok=True)
    results_dir.mkdir(exist_ok=True)
    
    if not args.skip_processing:
        print("\n=== Step 1: Processing Dataset ===")
        print("Extracting flattened contracts and running taint analysis...")
        start_time = time.time()
        
        import experiments.process_dataset as process_dataset
        process_dataset.main(convert_to_source=True)
        
        elapsed_time = time.time() - start_time
        print(f"Step 1: Processing completed in {elapsed_time:.2f} seconds")
    
    print("\n=== Step 2: Analyzing Results ===")
    print("Generating statistics from taint analysis results...")
    start_time = time.time()
    
    import experiments.analyze_results as analyze_results
    analyze_results.main("experiments/data/dataset/attack_dataset.xlsx")
    
    elapsed_time = time.time() - start_time
    print(f"Step 2: Analysis completed in {elapsed_time:.2f} seconds")
    
    print("\n=== Step 3: LLM-based Vulnerability Detection ===")
    print("Analyzing contracts with LLM to identify vulnerabilities...")
    
    models = ["qwen3-235b-a22b",
              "gpt-4.1",
              "ge-2.5-flash",
              ]
    all_results = {}
    
    print("\n=== Running PMDetector-NoLLM: Remove all LLM modules, including both path filtering and attack simulation ===")
    for model in models:
        all_results[f"PMDetector-NoLLM_{model}"] = run_taint_analysis_only_baseline(model, args.limit)

    combined_results_json_path = Path("pmdetector/llm_results.json")

    print("\n=== Step 4: Rule-based Sanity Check ===")
    print("Applying sanity checker to filter potential false positives...")
    
    for model in models:
            llm_results_path = Path(f"pmdetector/llm_results__{model.replace('-', '_')}.json")
            filtered_results_path = Path(f"pmdetector/filtered_llm_results__{model.replace('-', '_')}.json")
            
            if llm_results_path.exists():
                filtered_results = apply_sanity_check(llm_results_path, filtered_results_path)
                # calculate_filtered_metrics(filtered_results, f"{approach}_{model}")

                print("\n=== Experiment Complete ===")
                print(filtered_results)
            else:
                print("No result generated!")

def apply_sanity_check(llm_results_path, output_path=None):
        """Apply sanity checker to LLM results and save filtered results."""        
        with open(llm_results_path, 'r') as f:
            llm_results = json.load(f)   
        
        with open(llm_results_path, 'w') as f:
            json.dump(llm_results, f, indent=2)
        
        checker = SanityChecker()
        
        refined_results = {}
        flattened_dir = Path("pmdetector/flattened_contracts")

        valid_contracts = {}
        missing_contracts = []
        
        for contract_id, contract_data in llm_results.items():
            contract_file = flattened_dir / contract_id / "flattened.sol"
            if contract_file.exists() and contract_file.stat().st_size > 0:
                valid_contracts[contract_id] = contract_data
            else:
                missing_contracts.append(contract_id)

                refined_results[contract_id] = contract_data
        
        if missing_contracts:
            print(f"Step 4: Skipping sanity check for {len(missing_contracts)} contracts with missing source files")

        for contract_id, contract_data in valid_contracts.items():
            if not contract_data.get("is_vulnerable", False):
                refined_results[contract_id] = contract_data
                continue

            contract_file = flattened_dir / contract_id / "flattened.sol"
            print(f"Contract ID: {contract_id}")
            print(f"Contract File Path: {contract_file}")
                
            try:
                filtered_data = checker.check_vulnerabilities(str(contract_file), {contract_id: contract_data})
                refined_results[contract_id] = filtered_data[contract_id]

                if "ground_truth" in contract_data:
                    refined_results[contract_id]["ground_truth"] = contract_data["ground_truth"]
            except Exception as e:
                print(f"Step 4: Error applying sanity check to {contract_id}: {e}")
                refined_results[contract_id] = contract_data

        if output_path:
            with open(output_path, 'w') as f:
                json.dump(refined_results, f, indent=2)
            print(f"Step 4: Refined results with ground truth saved to: {output_path}")
        
        return refined_results
    

if __name__ == "__main__":
    main()
