"""
Path analyzer module for PMDetector.
This module provides the main functionality for analyzing taint paths,
grouping them, and generating narratives and evidence.
"""

import os
import json
import logging
from typing import List, Dict, Any, Optional, Union
from pathlib import Path

from pmdetector.llm.path_grouping import (
    EnhancedTaintPath, 
    parse_source_code_taint_path, 
    parse_all_taint_paths,
    group_paths
)
from pmdetector.llm.narrative_generator import (
    PathGroupNarrative,
    generate_narratives_for_groups,
    generate_output_json
)

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PathAnalyzer:
    def __init__(self, input_dir: str, output_dir: str):
        self.input_dir = input_dir
        self.output_dir = output_dir
      
        os.makedirs(output_dir, exist_ok=True)
    
    def analyze_contract(self, contract_name: str) -> Dict[str, Any]:
        """Analyze a single contract's taint paths."""
        logger.info(f"Analyzing contract: {contract_name}")
        
        # Parse taint paths
        input_file = os.path.join(self.input_dir, f"{contract_name}.txt")
        if not os.path.exists(input_file):
            logger.error(f"Input file not found: {input_file}")
            return {"error": f"Input file not found: {input_file}"}
        
        paths = parse_source_code_taint_path(input_file)
        if not paths:
            logger.warning(f"No taint paths found in {input_file}")
            return {"warning": f"No taint paths found in {input_file}"}
        
        logger.info(f"Found {len(paths)} taint paths")
        
        # Group paths
        grouped_paths = group_paths(paths)
        logger.info(f"Grouped into {len(grouped_paths)} path groups")
        
        # Generate narratives
        narratives = generate_narratives_for_groups(grouped_paths)
        
        # Generate output JSON
        output = generate_output_json(narratives)
        
        output["contract_name"] = contract_name
        output["total_paths"] = len(paths)
        output["total_groups"] = len(narratives)
        
        output_file = os.path.join(self.output_dir, f"{contract_name}_analysis.json")
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        
        logger.info(f"Wrote analysis results to {output_file}")
        
        return output
    
    def analyze_all_contracts(self) -> Dict[str, Dict[str, Any]]:
        """
        Analyze all contracts in the input directory.
        
        Returns:
            Dictionary mapping contract names to analysis results
        """
        logger.info(f"Analyzing all contracts in {self.input_dir}")
        
        results = {}
        contract_paths = parse_all_taint_paths(self.input_dir)
        
        for contract_name, paths in contract_paths.items():
            logger.info(f"Processing contract: {contract_name}")
            
            # Group paths
            grouped_paths = group_paths(paths)
            logger.info(f"Grouped into {len(grouped_paths)} path groups")
            
            # Generate narratives
            narratives = generate_narratives_for_groups(grouped_paths)
            
            # Generate output JSON
            output = generate_output_json(narratives)
            
            # Add contract metadata
            output["contract_name"] = contract_name
            output["total_paths"] = len(paths)
            output["total_groups"] = len(narratives)
            
            results[contract_name] = output
            
            # Write individual contract result to file
            output_file = os.path.join(self.output_dir, f"{contract_name}_analysis.json")
            with open(output_file, 'w') as f:
                json.dump(output, f, indent=2)
            
            logger.info(f"Wrote analysis results to {output_file}")
        
        return results
    
    def generate_text_report(self, analysis_result: Dict[str, Any]) -> str:
        """Generate a human-readable text report from the analysis result."""
        contract_name = analysis_result.get("contract_name", "Unknown Contract")
        total_paths = analysis_result.get("total_paths", 0)
        total_groups = analysis_result.get("total_groups", 0)
        
        report = []
        report.append(f"# Taint Analysis Report for {contract_name}")
        report.append(f"Found {total_paths} tainted paths grouped into {total_groups} path groups.")
        report.append("")
        
        path_groups = analysis_result.get("path_groups", [])
        for group in path_groups:
            group_id = group.get("group_id", 0)
            flow = group.get("flow", "")
            paths_represented = group.get("paths_represented", 0)
            narrative = group.get("narrative", "")
            
            report.append(f"## Path Group #{group_id}: {flow}")
            report.append(f"- Paths Represented: {paths_represented}")
            report.append("")
            report.append(f"- Narrative: {narrative}")
            report.append("")
            report.append("- Key Steps with Code Evidence:")
            
            key_evidence = group.get("key_evidence", [])
            for evidence in key_evidence:
                step_number = evidence.get("step_number", 0)
                code = evidence.get("code", "")
                file = evidence.get("file", "")
                line = evidence.get("line", 0)
                
                report.append(f"  {step_number}. `{code}` @ `{file}:{line}`")
            
            report.append("")
            report.append("----------------------------------------")
            report.append("")
        
        return "\n".join(report)
    
    def write_text_report(self, contract_name: str, report: str) -> str:
        """Write a text report to a file."""
        output_file = os.path.join(self.output_dir, f"{contract_name}_report.txt")
        with open(output_file, 'w') as f:
            f.write(report)
        
        logger.info(f"Wrote text report to {output_file}")
        return output_file


def analyze_contract(input_file: str, output_dir: str) -> Dict[str, Any]:
    """Analyze a single contract's taint paths."""
    contract_name = os.path.splitext(os.path.basename(input_file))[0]
    
    analyzer = PathAnalyzer(os.path.dirname(input_file), output_dir)
    result = analyzer.analyze_contract(contract_name)
    
    if "error" not in result and "warning" not in result:
        report = analyzer.generate_text_report(result)
        analyzer.write_text_report(contract_name, report)
    
    return result


def analyze_all_contracts(input_dir: str, output_dir: str) -> Dict[str, Dict[str, Any]]:
    """Analyze all contracts in the input directory."""
    analyzer = PathAnalyzer(input_dir, output_dir)

    results = analyzer.analyze_all_contracts()
    
    for contract_name, result in results.items():
        if "error" not in result and "warning" not in result:
            report = analyzer.generate_text_report(result)
            analyzer.write_text_report(contract_name, report)
    
    return results


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Analyze taint paths and generate reports.')
    parser.add_argument('--input-dir', type=str, default='pmdetector/taint_paths_with_source',
                        help='Directory containing taint path files')
    parser.add_argument('--output-dir', type=str, default='pmdetector/paths_group_results',
                        help='Directory to write output files')
    parser.add_argument('--contract', type=str, default=None,
                        help='Analyze a specific contract (filename without extension)')
    
    args = parser.parse_args()
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    if args.contract:
        # Analyze a specific contract
        input_file = os.path.join(args.input_dir, f"{args.contract}.txt")
        if not os.path.exists(input_file):
            logger.error(f"Input file not found: {input_file}")
            return
        
        analyze_contract(input_file, args.output_dir)
    else:
        # Analyze all contracts
        analyze_all_contracts(args.input_dir, args.output_dir)


if __name__ == '__main__':
    main()
