#!/usr/bin/env python3
"""
Script to clean up flattened Solidity contracts by:
1. Removing duplicate pragma statements (keeping only one)
2. Removing all import statements (since files are already flattened)
"""

import os
import re
from pathlib import Path

def clean_flattened_contract(file_path):
    """
    Clean a single flattened contract file by removing duplicate pragmas and imports.
    
    Args:
        file_path (str): Path to the flattened contract file
    
    Returns:
        bool: True if file was modified, False otherwise
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        lines = content.split('\n')
        cleaned_lines = []
        pragma_found = False
        
        for line in lines:
            stripped_line = line.strip()
            
            # Skip import statements entirely
            if stripped_line.startswith('import '):
                continue
            
            # Handle pragma statements - keep only the first one
            if stripped_line.startswith('pragma '):
                if not pragma_found:
                    cleaned_lines.append(line)
                    pragma_found = True
                # Skip subsequent pragma statements
                continue
            
            # Keep all other lines
            cleaned_lines.append(line)
        
        # Join lines back together
        cleaned_content = '\n'.join(cleaned_lines)
        
        # Remove excessive blank lines (more than 2 consecutive)
        cleaned_content = re.sub(r'\n\s*\n\s*\n+', '\n\n', cleaned_content)
        
        # Only write if content changed
        if cleaned_content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def process_flattened_contracts(base_dir):
    """
    Process all flattened contracts in the given directory.
    
    Args:
        base_dir (str): Base directory containing flattened contract folders
    """
    base_path = Path(base_dir)
    
    if not base_path.exists():
        print(f"Directory {base_dir} does not exist!")
        return
    
    processed_count = 0
    modified_count = 0
    
    # Find all flattened.sol files
    for contract_dir in base_path.iterdir():
        if contract_dir.is_dir():
            flattened_file = contract_dir / "flattened.sol"
            if flattened_file.exists():
                print(f"Processing: {flattened_file}")
                if clean_flattened_contract(str(flattened_file)):
                    modified_count += 1
                    print(f"  ✓ Cleaned up pragmas and imports")
                else:
                    print(f"  - No changes needed")
                processed_count += 1
    
    print(f"\nSummary:")
    print(f"  Processed: {processed_count} files")
    print(f"  Modified: {modified_count} files")

def main():
    """Main function to run the cleanup process."""
    # Get the script directory and construct the path relative to project root
    script_dir = Path(__file__).parent
    flattened_contracts_dir = script_dir / "flattened_contracts"
    
    print("Cleaning up flattened Solidity contracts...")
    print(f"Target directory: {flattened_contracts_dir}")
    print("-" * 50)
    
    process_flattened_contracts(str(flattened_contracts_dir))
    
    print("-" * 50)
    print("Cleanup completed!")

if __name__ == "__main__":
    main()
