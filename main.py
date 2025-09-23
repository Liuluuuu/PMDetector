#!/usr/bin/env python3
import os
import sys
import argparse
import json
import re
from pathlib import Path

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pmdetector.llm.multi_agents import MultiAgentAnalyzer
from pmdetector.core.detector import TaintDetector
from pmdetector.llm.path_abstraction import taint_result_to_source_text
from pmdetector.utils.blockchain import get_contract_source
from pmdetector.core.sanity_checker import SanityChecker
import warnings
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL 1.1.1+")

from cleanup_flattened_contracts import clean_flattened_contract
from experiments.process_dataset import extract_solidity_version, ensure_solc_version, adapt_pragma_to_version

# Initialize necessary directories
def init_directories():
    base_dir = Path(__file__).parent
    flattened_dir = base_dir / "flattened_contracts"
    results_dir = base_dir / "analysis_results"
    taint_paths_dir = base_dir / "taint_paths_with_source"
    
    flattened_dir.mkdir(exist_ok=True)
    results_dir.mkdir(exist_ok=True)
    taint_paths_dir.mkdir(exist_ok=True)
    
    return base_dir, flattened_dir, results_dir, taint_paths_dir


def fetch_contract_source_code(contract_address, platform):
    try:
        platform_mapping = {
            'ETH': 'ethereum',
            'Base': 'base',
            'BSC': 'bsc',
            'ARB': 'arb',
            'Polygon': 'polygon',
        }
        
        blockchain_name = platform_mapping.get(platform, 'ethereum')
        
        print(f"Fetching contract {contract_address} from {platform}")
        
        source_code = get_contract_source(contract_address, blockchain_name)
        
        if source_code:
            if isinstance(source_code, dict):
                flattened_source = ""
                for file_path, content in source_code.items():
                    if file_path.endswith('.sol'):
                        flattened_source += f"\n// Source: {file_path}\n"
                        flattened_source += content + "\n"
                return flattened_source.strip() if flattened_source else None
            else:
                return source_code
        else:
            print(f"No source code found for {contract_address}")
            return None
            
    except Exception as e:
        print(f"Error fetching contract {contract_address}: {e}")
        return None

def create_taint_path_files(contract_id, taint_result, base_dir):
    """
    Create taint path files for LLM analysis.
    """
    try:
        taint_paths_dir = base_dir / "taint_paths_with_source"
        taint_paths_dir.mkdir(exist_ok=True)
        
        taint_path_file = taint_paths_dir / f"{contract_id}.json"
        
        taint_data = {
            "contract_id": contract_id,
            "paths": []
        }
        
        for i, (source, sink, operations) in enumerate(taint_result.paths):
            path_data = {
                "path_id": i + 1,
                "source": {
                    "type": source.source_type,
                    "operation": str(source.operation)
                },
                "sink": {
                    "type": sink.sink_type,
                    "operation": str(sink.operation)
                },
                "operations": [str(op) for op in operations]
            }
            taint_data["paths"].append(path_data)

        with open(taint_path_file, 'w') as f:
            json.dump(taint_data, f, indent=2)
        
        print(f"Created taint path file for {contract_id}")
        
    except Exception as e:
        print(f"Error creating taint path files for {contract_id}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Run PMDetector for identifying price manipulation vulnerabilities.")
    parser.add_argument("--contract-address", type=str, help="Contract address to analyze")
    parser.add_argument("--platform", type=str, default="ETH", help="Blockchain platform (e.g., ETH, BSC)")
    parser.add_argument("--source-code", type=str, help="Path to contract source code file")
    args = parser.parse_args()
    
    base_dir, flattened_dir, results_dir, taint_paths_dir = init_directories()
    
    if args.contract_address or args.source_code:
        process_single_contract(args)
    else:
        print("Error: Please provide either a contract address or a source code file path.")
        print("Example usage:")
        print("  python main.py --contract-address 0x123abc --platform ETH")
        print("  python main.py --source-code path/to/contract.sol")


def process_single_contract(args):
    base_dir = Path(__file__).parent
    flattened_dir = base_dir / "flattened_contracts"
    results_dir = base_dir / "analysis_results"
    taint_paths_dir = base_dir / "taint_paths_with_source"
    
    if args.contract_address:
        contract_id = f"{args.contract_address}_{args.platform}"
        print(f"Processing contract: {args.contract_address} on {args.platform}")
        
        contract_dir = flattened_dir / contract_id
        contract_dir.mkdir(exist_ok=True)
        
        contract_file = contract_dir / "flattened.sol"
        if not contract_file.exists():
            source_code = fetch_contract_source_code(args.contract_address, args.platform)
            if source_code:
                contract_file.write_text(source_code)
                print(f"Successfully fetched source code for {contract_id}")
                
                # Clean up the flattened contract file
                try:
                    if clean_flattened_contract(str(contract_file)):
                        print(f"  ✓ Cleaned up pragmas and imports for {contract_id}")
                    else:
                        print(f"  - No cleanup needed for {contract_id}")
                except Exception as e:
                    print(f"  Warning: Error cleaning up {contract_id}: {e}")
            else:
                print(f"Error: Could not fetch source code for {args.contract_address} on {args.platform}")
                return
    elif args.source_code:
        source_path = Path(args.source_code)
        if not source_path.exists():
            print(f"Error: Source code file not found: {args.source_code}")
            return
        
        contract_id = source_path.stem
        print(f"Processing contract from file: {args.source_code}")
        
        contract_dir = flattened_dir / contract_id
        contract_dir.mkdir(exist_ok=True)

        contract_file = contract_dir / "flattened.sol"
        with open(source_path, 'r') as src_file:
            source_code = src_file.read()
            contract_file.write_text(source_code)
        
        # Clean up the flattened contract file
        try:
            if clean_flattened_contract(str(contract_file)):
                print(f"  ✓ Cleaned up pragmas and imports for {contract_id}")
            else:
                print(f"  - No cleanup needed for {contract_id}")
        except Exception as e:
            print(f"  Warning: Error cleaning up {contract_id}: {e}")
    else:
        print("Error: Either contract address or source code file must be provided")
        return
    
    print(f"\n=== Running Taint Analysis on {contract_id} ===")
    detector = TaintDetector()
    result_file = results_dir / f"{contract_id}.txt"
    
    try:
        # Extract and set Solidity version from pragma
        try:
            solidity_version = extract_solidity_version(str(contract_file))
            print(f"Extracted Solidity version {solidity_version} from {contract_id}")
            
            solc_path = ensure_solc_version(solidity_version)
            print(f"Using solc version {solidity_version} (path: {solc_path})")
            
            actual_version = solidity_version
            match = re.search(r'solc-v(\d+\.\d+\.\d+)', solc_path)
            if match:
                actual_version = match.group(1)
            
            from solcx import set_solc_version, get_solc_version
            set_solc_version(actual_version, silent=False)
            
            if actual_version != solidity_version:
                print(f"Adapting pragma from {solidity_version} to {actual_version}")
                adapt_pragma_to_version(contract_file, actual_version)
                
            source_code = contract_file.read_text()
                
        except Exception as e:
            print(f"Warning: Error setting Solidity version for {contract_id}: {e}")
            print("Proceeding with default version 0.8.21")
            
            fallback_version = "0.8.21"     # Fallback to a stable version
            solc_path = ensure_solc_version(fallback_version)
            from solcx import set_solc_version
            set_solc_version(fallback_version, silent=False)
        
        # Run taint analysis
        taint_result = detector.analyze_file(contract_file, solc_path=solc_path)
        
        if taint_result and taint_result.paths:
            source_text = taint_result_to_source_text(taint_result, source_code)
            
            result_file.write_text(source_text)
            print(f"Successfully analyzed {contract_id}: Found {len(taint_result.paths)} taint paths")

            create_taint_path_files(contract_id, taint_result, base_dir)
            
            print("\n=== Taint Analysis Results ===")
            print(source_text)
            
            # Apply LLM-based Analysis
            print("\n=== Running LLM Analysis ===")
            model = "gpt-4"  # Using OpenAI's GPT-4 model
            analyzer = MultiAgentAnalyzer(model=model)
            
            with open(result_file, "r", encoding="utf-8") as f:
                result_content = f.read()
            
            taint_paths = []
            lines = result_content.split("\n")
            current_path = []
            in_path = False
            
            for line in lines:
                if line.startswith("=== Taint Path") or line.startswith("## Path #"):
                    if current_path:
                        taint_paths.append("\n".join(current_path))
                        current_path = []
                    in_path = True
                    current_path.append(line)
                elif in_path:
                    current_path.append(line)
            
            if current_path:
                taint_paths.append("\n".join(current_path))
            
            if taint_paths:
                try:
                    result = analyzer.analyze(source_code, taint_paths, contract_id)
                    
                    print("\n=== LLM Analysis Results ===")
                    print(f"Is Vulnerable: {result.get('is_vulnerable', False)}")
                    print(f"Confidence: {result.get('confidence', 0.0)}")
                    print(f"Explanation: {result.get('explanation', 'No explanation provided')}")
                    
                    if result.get('vulnerable_functions'):
                        print("\nVulnerable Functions:")
                        for func in result.get('vulnerable_functions', []):
                            print(f"- {func}")
                    
                    if result.get('vulnerable_groups'):
                        print("\nVulnerable Path Groups:")
                        for group in result.get('vulnerable_groups', []):
                            print(f"- Group #{group.get('group_id', 'unknown')}: {group.get('explanation', 'No explanation')}")
                    
                    result_json_path = base_dir / f"{contract_id}_llm_result.json"
                    with open(result_json_path, 'w') as f:
                        json.dump(result, f, indent=2)
                    
                    print(f"\nLLM analysis results saved to: {result_json_path}")
                except Exception as e:
                    print(f"Error analyzing {contract_id}: {e}")
                    print(f"Analysis failed for {contract_id}")
                    # Create a default result for the sanity check
                    result = {
                        "is_vulnerable": False,
                        "confidence": 0.0,
                        "explanation": f"Error during LLM analysis: {str(e)}",
                        "vulnerable_functions": [],
                        "vulnerable_paths": [],
                        "vulnerable_groups": []
                    }
                
                # Apply rule-based sanity check
                print("\n=== Running Rule-based Sanity Check ===")
                print("Applying sanity checker to filter potential false positives...")
                
                filtered_result = apply_sanity_check(contract_id, result, str(contract_file))
                
                result = filtered_result
                
                filtered_result_path = base_dir / f"{contract_id}_filtered_llm_result.json"
                with open(filtered_result_path, 'w') as f:
                    json.dump(filtered_result, f, indent=2)
                
                print(f"\nFiltered LLM analysis results saved to: {filtered_result_path}")
            else:
                print("No taint paths found for LLM analysis")
        else:
            result_file.write_text("No taint paths found.")
            print(f"Analyzed {contract_id}: No taint paths found")
            print("\nNo vulnerabilities detected in the contract.")
    except Exception as e:
        print(f"Error analyzing {contract_id}: {e}")
        result_file.write_text(f"Error during analysis: {str(e)}")
        print(f"Analysis failed for {contract_id}")


def apply_sanity_check(contract_id, llm_result, contract_file_path):
    """
    Apply sanity checker to LLM results and filter potential false positives.
    """
    try:
        print(f"Applying sanity check to {contract_id}...")
        
        if not llm_result.get("is_vulnerable", False):
            print(f"Contract {contract_id} is not vulnerable, skipping sanity check.")
            return llm_result
        
        checker = SanityChecker()
        filtered_results = checker.check_vulnerabilities(contract_file_path, {contract_id: llm_result})
        
        filtered_result = filtered_results[contract_id]
        
        if filtered_result.get("is_vulnerable", False):
            print(f"Sanity check confirms vulnerability in {contract_id}")
            if "filter_status" in filtered_result:
                print(f"Filter status: {filtered_result['filter_status']}")
            if "filter_reason" in filtered_result:
                print(f"Filter reason: {filtered_result['filter_reason']}")
        else:
            print(f"Sanity check filtered out vulnerability in {contract_id} as likely false positive")
            if "filter_status" in filtered_result:
                print(f"Filter status: {filtered_result['filter_status']}")
            if "filter_reason" in filtered_result:
                print(f"Filter reason: {filtered_result['filter_reason']}")
        
        return filtered_result
        
    except Exception as e:
        print(f"Error applying sanity check to {contract_id}: {e}")
        return llm_result


if __name__ == "__main__":
    main()
