#!/usr/bin/env python3
"""
Example script demonstrating how to use PMDetector to analyze a smart contract.
"""

import os
import sys
from pathlib import Path

# Add the parent directory to the Python path to import pmdetector
sys.path.insert(0, str(Path(__file__).parent.parent))

from pmdetector.core.detector import TaintDetector


def main():
    """Analyze the example price manipulation contract."""
    # Create a detector instance
    detector = TaintDetector(verbose=True)
    
    # Get the path to the example contract
    contract_path = Path(__file__).parent / "price_manipulation.sol"
    
    print(f"Analyzing contract: {contract_path}")
    print("=" * 80)
    
    try:
        # Run the analysis
        result = detector.analyze_file(contract_path)
        
        # Print the results
        print(result.to_text())
        
        # Check if vulnerabilities were found
        if result.has_vulnerabilities():
            print("\nVulnerabilities detected!")
            print(f"Found {len(result.paths)} vulnerable paths from taint sources to sinks.")
            
            # Print details about each path
            for i, (source, sink, path) in enumerate(result.paths, 1):
                print(f"\nVulnerable Path #{i}:")
                print(f"  Source: {source}")
                print(f"  Sink: {sink}")
                print("  Operations in path:")
                for j, op in enumerate(path, 1):
                    print(f"    {j}. {op}")
        else:
            print("\nNo vulnerabilities detected.")
        
    except Exception as e:
        print(f"Error analyzing contract: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
