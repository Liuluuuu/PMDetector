"""
Parser for taint paths from text files.
"""

import re
import os
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple, Union


class TaintPathOperation:
    """
    Represents a single operation in a taint path.
    """
    def __init__(self, ir: str, src_file: str, src_lines: List[int], code: str):
        self.ir = ir
        self.src_file = src_file
        self.src_lines = src_lines
        self.code = code

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the operation to a dictionary representation.
        """
        return {
            "ir": self.ir,
            "src_file": self.src_file,
            "src_lines": self.src_lines,
            "code": self.code
        }


class TaintPath:
    """
    Represents a complete taint path from source to sink.
    """
    def __init__(self, path_id: str, source: str, sink: str, operations: List[TaintPathOperation]):
        self.path_id = path_id
        self.source = source
        self.sink = sink
        self.operations = operations

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the taint path to a dictionary representation.
        """
        return {
            "path_id": self.path_id,
            "source": self.source,
            "sink": self.sink,
            "operations": [op.to_dict() for op in self.operations]
        }


def parse_taint_path_file(file_path: str) -> List[TaintPath]:
    """Parse a taint path file and extract all taint paths. """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading taint path file {file_path}: {e}")
        return []
    
    try:
        # Extract the number of paths
        paths_count_match = re.search(r'Found (\d+) tainted paths', content)
        if not paths_count_match:
            print(f"No tainted paths found in {file_path}")
            return []
        
        # Split the content by path sections
        path_sections = re.split(r'## Path #\d+', content)[1:]  # Skip the header
        
        paths = []
        for i, section in enumerate(path_sections, 1):
            try:
                path_id = f"Path #{i}"
                
                # Extract source and sink
                source_match = re.search(r'Source: (.*?) in (.*?)$', section, re.MULTILINE)
                sink_match = re.search(r'Sink: (.*?) in (.*?)$', section, re.MULTILINE)
                
                if not source_match or not sink_match:
                    print(f"Missing source or sink in {path_id} of {file_path}")
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
                    print(f"No operations found in {path_id} of {file_path}")
                    continue
                
                operations_text = operations_section.group(1).strip()
                operation_blocks = re.split(r'\n\s*\n', operations_text)
                
                operations = []
                for block in operation_blocks:
                    try:
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
                        
                        operations.append(TaintPathOperation(ir, src_file, src_lines, code))
                    except Exception as e:
                        print(f"Error parsing operation block in {path_id} of {file_path}: {e}")
                        # Continue with the next operation block
                
                if operations:  # Only add the path if it has operations
                    paths.append(TaintPath(path_id, source, sink, operations))
                else:
                    print(f"No valid operations found in {path_id} of {file_path}")
            except Exception as e:
                print(f"Error parsing path section {i} in {file_path}: {e}")
                # Continue with the next path section
        
        return paths
    except Exception as e:
        print(f"Error parsing taint path file {file_path}: {e}")
        return []


def parse_all_taint_paths(directory: str) -> Dict[str, List[TaintPath]]:
    """
    Parse all taint path files in a directory.
    """
    result = {}
    
    for file_path in Path(directory).glob('*.txt'):
        contract_name = file_path.stem
        paths = parse_taint_path_file(str(file_path))
        if paths:
            result[contract_name] = paths
    
    return result
