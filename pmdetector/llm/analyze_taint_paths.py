#!/usr/bin/env python3
"""
Command-line interface for analyzing taint paths.
"""

import os
import sys
import argparse
import logging
from pathlib import Path

from pmdetector.llm.path_analyzer import analyze_contract, analyze_all_contracts

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Analyze taint paths and generate reports.')
    parser.add_argument('--input-dir', type=str, default='pmdetector/taint_paths_with_source',
                        help='Directory containing taint path files')
    parser.add_argument('--output-dir', type=str, default='pmdetector/taint_analysis_results',
                        help='Directory to write output files')
    parser.add_argument('--contract', type=str, default=None,
                        help='Analyze a specific contract (filename without extension)')
    parser.add_argument('--llm-service', type=str, default='openai', choices=['openai'],
                        help='Narrative generation uses an OpenAI-compatible HTTP endpoint')
    parser.add_argument('--llm-api-key', type=str, default=None,
                        help='API key for the LLM service')
    parser.add_argument('--llm-model', type=str, default=None,
                        help='Model to use for the LLM service')
    
    args = parser.parse_args()
    
    # Set environment variables for LLM service
    if args.llm_service:
        os.environ["LLM_SERVICE"] = args.llm_service
    if args.llm_api_key:
        os.environ["LLM_API_KEY"] = args.llm_api_key
        os.environ["LLM_KEY"] = "Bearer " + args.llm_api_key
    if args.llm_model:
        os.environ["LLM_MODEL"] = args.llm_model
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)
    
    if args.contract:
        # Analyze a specific contract
        input_file = os.path.join(args.input_dir, f"{args.contract}.txt")
        if not os.path.exists(input_file):
            logger.error(f"Input file not found: {input_file}")
            return 1
        
        result = analyze_contract(input_file, args.output_dir)
        if "error" in result:
            logger.error(result["error"])
            return 1
        if "warning" in result:
            logger.warning(result["warning"])
            return 0
        
        logger.info(f"Successfully analyzed contract: {args.contract}")
        logger.info(f"Found {result['total_paths']} taint paths grouped into {result['total_groups']} path groups")
        logger.info(f"Results written to {args.output_dir}/{args.contract}_analysis.json")
        logger.info(f"Report written to {args.output_dir}/{args.contract}_report.txt")
    else:
        # Analyze all contracts
        results = analyze_all_contracts(args.input_dir, args.output_dir)
        if not results:
            logger.error("No contracts found to analyze")
            return 1
        
        logger.info(f"Successfully analyzed {len(results)} contracts")
        logger.info(f"Results written to {args.output_dir}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
