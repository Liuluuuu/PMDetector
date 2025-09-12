"""
Path grouping module for PMDetector.
This module provides functions to group taint paths based on source, sink, and critical operations.
"""

import re
import os
from collections import defaultdict
from typing import List, Dict, Tuple, Set, Any, Optional, Union
from pathlib import Path

from pmdetector.llm.path_parser import TaintPath


class PathOperation:
    """Represents a single operation in a taint path."""
    def __init__(self, ir: str, file: str, lines: List[int], code: str):
        self.ir = ir
        self.file = file
        self.lines = lines
        self.code = code
        # Extract key info for easier access
        self.is_call = "CALL" in self.ir
        self.is_state_write = ":=" in self.ir and "[" in self.ir  # Heuristic for state writes
        self.call_target = self._extract_call_target()

    def _extract_call_target(self) -> str:
        if self.is_call:
            # Simple regex to get the function signature from the IR
            match = re.search(r"(\w+\._\w+|\w+\.\w+)", self.ir)
            return match.group(1) if match else "Unknown Call"
        return ""
        
    def __repr__(self):
        return f"Op(IR='{self.ir}', Code='{self.code}')"


class EnhancedTaintPath:
    """Enhanced version of TaintPath with additional functionality."""
    def __init__(self, path_id: str, source: str, sink: str, operations: List[PathOperation]):
        self.id = path_id
        self.source = source
        self.sink = sink
        self.operations = operations
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the EnhancedTaintPath object to a dictionary."""
        source_parts = self.source.split(" in ")
        source_type = source_parts[0] if len(source_parts) > 0 else ""
        source_function = source_parts[1] if len(source_parts) > 1 else self.source
        
        sink_parts = self.sink.split(" in ")
        sink_type = sink_parts[0] if len(sink_parts) > 0 else ""
        sink_function = sink_parts[1] if len(sink_parts) > 1 else self.sink
        
        steps = []
        for op in self.operations:
            step = {
                "operation": op.ir,
                "file": op.file,
                "line": op.lines[0] if op.lines else 0,
                "code": op.code
            }
            steps.append(step)
        
        return {
            "id": self.id,
            "source": {
                "type": source_type,
                "function": source_function,
                "file": steps[0]["file"] if steps else "",
                "line": steps[0]["line"] if steps else 0
            },
            "sink": {
                "type": sink_type,
                "function": sink_function,
                "file": steps[-1]["file"] if steps else "",
                "line": steps[-1]["line"] if steps else 0
            },
            "steps": steps
        }
        
    @property
    def source_function(self) -> str:
        # Extracts 'CToken.initialize' from 'external_input in CToken.initialize'
        parts = self.source.split(" in ")
        if len(parts) > 1:
            return parts[1]
        return self.source

    @property
    def sink_function(self) -> str:
        # Extracts 'CToken.accrueInterest' from '... in CToken.accrueInterest'
        parts = self.sink.split(" in ")
        if len(parts) > 1:
            return parts[1]
        return self.sink
    
    def get_critical_operations(self) -> List[str]:
        """
        Identify critical operations in this path.
        Critical operations include external calls and state variable writes.
        """
        critical_ops = []
        for op in self.operations:
            if op.is_call:
                # We only care about the function being called, not the arguments
                critical_ops.append(op.call_target)
            elif op.is_state_write:
                # Extract the state variable name (e.g., _balances)
                match = re.search(r"(\w+)\[", op.code)
                if match:
                    critical_ops.append(f"write_to_{match.group(1)}")
        
        return critical_ops


def convert_taint_path_to_enhanced(path: TaintPath) -> EnhancedTaintPath:
    """
    Convert a TaintPath object to an EnhancedTaintPath object.
    """
    operations = []
    for op in path.operations:
        operations.append(PathOperation(
            ir=op.ir,
            file=op.src_file,
            lines=op.src_lines,
            code=op.code
        ))
    
    return EnhancedTaintPath(
        path_id=path.path_id,
        source=path.source,
        sink=path.sink,
        operations=operations
    )


def group_paths(all_paths: List[EnhancedTaintPath]) -> Dict[Tuple, List[EnhancedTaintPath]]:
    """
    Groups paths based on source, sink, and critical operations.
    """
    path_groups = defaultdict(list)
    
    for path in all_paths:
        critical_ops = path.get_critical_operations()

        group_key = (
            path.source_function,
            path.sink_function,
            frozenset(critical_ops)
        )
        
        path_groups[group_key].append(path)
        
    return path_groups


def parse_source_code_taint_path(file_path: str) -> List[EnhancedTaintPath]:
    """
    Parse a taint path file with source code mapping and convert to EnhancedTaintPath objects.
    """
    with open(file_path, 'r') as f:
        content = f.read()
    
    paths_count_match = re.search(r'Found (\d+) tainted paths', content)
    if not paths_count_match:
        return []
    
    path_sections = re.split(r'## Path #\d+', content)[1:] 
    
    paths = []
    for i, section in enumerate(path_sections, 1):
        path_id = f"Path #{i}"
        
        # Extract source and sink
        source_match = re.search(r'Source: (.*?) in (.*?)$', section, re.MULTILINE)
        sink_match = re.search(r'Sink: (.*?) in (.*?)$', section, re.MULTILINE)
        
        if not source_match or not sink_match:
            continue
        
        source_type = source_match.group(1).strip()
        source_location = source_match.group(2).strip()
        source = f"{source_type} in {source_location}"
        
        sink_type = sink_match.group(1).strip()
        sink_location = sink_match.group(2).strip()
        sink = f"{sink_type} in {sink_location}"
        
        # Extract operations
        operations_section = re.search(r'### Operations with Source Code Mapping:(.*?)(?:----+|$)', section, re.DOTALL)
        if not operations_section:
            continue
        
        operations_text = operations_section.group(1).strip()
        operation_blocks = re.split(r'\n\s*\n', operations_text)
        
        operations = []
        for block in operation_blocks:
            if not block.strip():
                continue
            
            ir_match = re.search(r'IR:\s+(.*?)$', block, re.MULTILINE)
            src_match = re.search(r'SRC: File \'(.*?)\', Lines \[(.*?)\]', block)
            code_match = re.search(r'LNE:\s+(.*?)$', block, re.MULTILINE)
            
            if not ir_match or not src_match:
                continue
            
            ir = ir_match.group(1).strip()
            src_file = src_match.group(1).strip()
            
            # Parse the line numbers
            src_lines_str = src_match.group(2).strip()
            src_lines = []
            for part in src_lines_str.split(','):
                part = part.strip()
                if part.isdigit():
                    src_lines.append(int(part))
            
            code = code_match.group(1).strip() if code_match else "(No direct expression available)"
            
            operations.append(PathOperation(ir, src_file, src_lines, code))
        
        paths.append(EnhancedTaintPath(path_id, source, sink, operations))
    
    return paths


def parse_all_taint_paths(directory: str) -> Dict[str, List[EnhancedTaintPath]]:
    """
    Parse all taint path files in a directory.
    """
    result = {}
    
    for file_path in Path(directory).glob('*.txt'):
        contract_name = file_path.stem
        paths = parse_source_code_taint_path(str(file_path))
        if paths:
            result[contract_name] = paths
    
    return result


def format_path_groups(path_groups: Union[Dict, List], contract_id: Optional[str] = None, baseline_name: Optional[str] = None) -> str:
    """
    Format path groups for inclusion in the prompt.
    Only keeps paths with the longest operation sequences for each group.
    """
    if baseline_name:
        # Create the directory if it doesn't exist 
        path_groups_dir = Path(f"pmdetector/formatted_path_groups_{baseline_name}") 
        path_groups_dir.mkdir(exist_ok=True) 
        
        # Create a new directory for filtered paths ready for z3 solver checking
        filtered_paths_dir = Path(f"pmdetector/filtered_taint_paths_{baseline_name}")
        filtered_paths_dir.mkdir(exist_ok=True)
    else:
        # Use default directories
        path_groups_dir = Path("pmdetector/formatted_path_groups") 
        path_groups_dir.mkdir(exist_ok=True) 
        
        filtered_paths_dir = Path("pmdetector/filtered_taint_paths")
        filtered_paths_dir.mkdir(exist_ok=True)
    
    # Check if there's already a formatted path group file for this contract
    if contract_id:
        filename = f"{contract_id}_path_groups.txt"
        output_path = path_groups_dir / filename
        
        if output_path.exists():
            print(f"File {output_path} already exists, reusing content")
            with open(output_path, "r") as f:
                return f.read()
    
    # If no existing file or no contract_id provided, generate new formatted path groups
    result = []
    result.append("Path Groups:")
    
    # Dictionary to store filtered paths for each contract
    filtered_paths_by_contract = {}
    
    # Handle both dictionary and list formats
    if isinstance(path_groups, dict):
        # Original format: dictionary with tuple keys
        for i, (group_key, paths) in enumerate(path_groups.items(), 1):
            source_func, sink_func, critical_ops = group_key
        
            # Filter paths to keep only the ones with the longest operation sequences
            if len(paths) > 1:
                # Find the path with the most operations
                longest_path = max(paths, key=lambda p: len(p.operations))
                filtered_paths = [longest_path]
                
                print(f"Group #{i}: Keeping only path {longest_path.id} with {len(longest_path.operations)} operations")
                for path in paths:
                    if path != longest_path:
                        print(f"  - Filtering out path {path.id} with {len(path.operations)} operations")
            else:
                filtered_paths = paths
            
            # Store filtered paths for later use
            if contract_id:
                if contract_id not in filtered_paths_by_contract:
                    filtered_paths_by_contract[contract_id] = []
                filtered_paths_by_contract[contract_id].extend(filtered_paths)
            
            # Extract key evidence from the filtered paths
            key_evidence = extract_key_evidence(filtered_paths)
            
            # Extract affected state variables
            affected_state_vars = extract_affected_state_vars(filtered_paths)
            
            # Format the key steps for display
            formatted_key_steps = []
            for ev in key_evidence:
                formatted_key_steps.append(f"- `{ev['code']}` @ `{ev['file']}:{ev['line']}`")
            
            result.append(f"Group #{i}:")
            result.append(f"  Source Function: {source_func}")
            result.append(f"  Sink Function: {sink_func}")
            result.append(f"  Critical Operations: {', '.join(sorted(critical_ops))}")
            result.append(f"  Affected State: {', '.join(sorted(list(affected_state_vars)))}")
            result.append(f"  Paths in this group: {len(filtered_paths)}")
            
            # Include path IDs in this group
            path_ids = [path.id for path in filtered_paths]
            result.append(f"  Path IDs: {', '.join(path_ids)}")
            
            # Include key steps
            result.append("  Key Steps:")
            for step in formatted_key_steps:
                result.append(f"    {step}")
            
            result.append("")
    else:
        # New format: list of dictionaries
        for group in path_groups:
            i = group.get("group_id", 0)
            source_func = group.get("source_function", "Unknown")
            sink_func = group.get("sink_function", "Unknown")
            critical_ops = group.get("critical_operations", [])
            paths = group.get("paths", [])
            
            # Filter paths to keep only the ones with the longest operation sequences
            if len(paths) > 1:
                # Find the path with the most operations
                longest_path = max(paths, key=lambda p: len(p.operations))
                filtered_paths = [longest_path]

                print(f"Group #{i}: Keeping only path {longest_path.id} with {len(longest_path.operations)} operations")
                for path in paths:
                    if path != longest_path:
                        print(f"  - Filtering out path {path.id} with {len(path.operations)} operations")
            else:
                filtered_paths = paths
            
            # Store filtered paths for later use
            if contract_id:
                if contract_id not in filtered_paths_by_contract:
                    filtered_paths_by_contract[contract_id] = []
                filtered_paths_by_contract[contract_id].extend(filtered_paths)
            
            # Extract key evidence from the filtered paths
            key_evidence = extract_key_evidence(filtered_paths)
            
            # Extract affected state variables
            affected_state_vars = extract_affected_state_vars(filtered_paths)
            
            # Format the key steps for display
            formatted_key_steps = []
            for ev in key_evidence:
                formatted_key_steps.append(f"- `{ev['code']}` @ `{ev['file']}:{ev['line']}`")
            
            result.append(f"Group #{i}:")
            result.append(f"  Source Function: {source_func}")
            result.append(f"  Sink Function: {sink_func}")
            result.append(f"  Critical Operations: {', '.join(sorted(str(op) for op in critical_ops))}")
            result.append(f"  Affected State: {', '.join(sorted(list(affected_state_vars)))}")
            result.append(f"  Paths in this group: {len(filtered_paths)}")
            
            # Include path IDs in this group
            path_ids = [path.id for path in filtered_paths]
            result.append(f"  Path IDs: {', '.join(path_ids)}")
            
            # Include key steps
            result.append("  Key Steps:")
            for step in formatted_key_steps:
                result.append(f"    {step}")
            
            result.append("")
    
    # Store the formatted path groups in a dedicated folder
    formatted_result = "\n".join(result)
    if contract_id:
        filename = f"{contract_id}_path_groups.txt"
        output_path = path_groups_dir / filename
        
        if not output_path.exists():
            with open(output_path, "w") as f:
                f.write(formatted_result)
            
            print(f"Stored formatted path groups to {output_path}")
        
        # Write filtered paths to the new directory in the same format as taint_paths_with_source
        if contract_id in filtered_paths_by_contract:
            filtered_paths = filtered_paths_by_contract[contract_id]
            filtered_path_content = _generate_taint_path_content(filtered_paths)
            
            filtered_path_file = filtered_paths_dir / f"{contract_id}.txt"
            with open(filtered_path_file, "w") as f:
                f.write(filtered_path_content)

            print(f"Stored filtered paths to {filtered_path_file}")
    
    return formatted_result

def _generate_taint_path_content(paths: List[EnhancedTaintPath]) -> str:
    """Generate content for taint path file in the same format as taint_paths_with_source."""
    result = []
    result.append("# Taint Analysis Results with Source Code Mapping")
    result.append(f"Found {len(paths)} tainted paths.")
    result.append("")
    
    for path in paths:
        result.append(f"## {path.id}")
        result.append(f"Source: {path.source}")
        result.append(f"Sink: {path.sink}")
        result.append("")
        result.append("### Operations with Source Code Mapping:")
        
        for op in path.operations:
            result.append(f"    IR:  {op.ir}")
            result.append(f"    SRC: File '{op.file}', Lines {op.lines}")
            result.append(f"    LNE: {op.code}")
            result.append("")
        
        result.append("----------------------------------------")
        result.append("")
    
    return "\n".join(result)


def extract_key_evidence(paths: List[EnhancedTaintPath], max_evidence: int = 5) -> List[Dict[str, str]]:
    """
    Extract key evidence from a group of paths.
    """
    all_operations = []
    for path in paths:
        for op in path.operations:
            if op.code and op.code != "(No direct expression available)":
                # Create a unique key for the operation to avoid duplicates
                all_operations.append({
                    "code": op.code,
                    "file": os.path.basename(op.file),
                    "line": op.lines[0] if op.lines else 0,
                    "ir": op.ir
                })
    
    # Sort operations by line number to maintain logical flow
    all_operations.sort(key=lambda x: x["line"])
    
    # Remove duplicates while preserving order
    unique_operations = []
    seen = set()
    for op in all_operations:
        key = (op["code"], op["file"], op["line"])
        if key not in seen:
            seen.add(key)
            unique_operations.append(op)
    
    # Limit to max_evidence
    evidence = unique_operations[:max_evidence]
    
    # Add step numbers
    for i, ev in enumerate(evidence, 1):
        ev["step_number"] = i
    
    return evidence

def extract_affected_state_vars(paths: List[EnhancedTaintPath]) -> Set[str]:
    """
    Extract affected state variables from a group of paths.
    """
    affected_vars = set()
    
    for path in paths:
        for op in path.operations:
            # Find variable names from state write operations
            if op.is_state_write:
                match = re.search(r"(\w+)\[", op.code)
                if match:
                    affected_vars.add(match.group(1))
            
            # Find variable names from IR assignments (e.g., comptroller := ...)
            match_assign = re.match(r"\s*(\w+)\(.*\)\s*:=", op.ir)
            if match_assign:
                affected_vars.add(match_assign.group(1))
    
    return affected_vars
