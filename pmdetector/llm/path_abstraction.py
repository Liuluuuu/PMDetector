"""
Path abstraction module for PMDetector.
This module provides functions to map SlitherIR taint paths back to source code.
"""

import json
import re
from typing import Dict, List, Optional, Any, Tuple, Union
from pmdetector.core.taint_result import TaintResult
from pmdetector.core.taint_source import TaintSource
from pmdetector.core.taint_sink import TaintSink
from slither.slithir.operations import Operation
from slither.core.declarations import Function


def taint_result_to_source_text(taint_result: TaintResult, source_code: Dict[str, str], verbose: bool = False) -> str:
    """
    Maps LIVE taint paths to source code using Slither's source mappings.
    This function ONLY accepts a live TaintResult object.
    """
    result = []
    result.append("# Taint Analysis Results with Source Code Mapping")
    result.append(f"Found {len(taint_result.paths)} tainted paths.")
    result.append("")
    
    if not taint_result.paths:
        result.append("No relevant paths found in the taint analysis.")
        return "\n".join(result)
    
    for i, (source, sink, operations) in enumerate(taint_result.paths, 1):
        # Handle the case where source.operation might be a Function object itself
        source_op = source.operation
        sink_op = sink.operation
        
        # Get contract and function names from source
        source_contract_name = "UnknownContract"
        source_function_name = "UnknownFunction"
        
        # First check if source.contract and source.function are directly available
        if hasattr(source, 'contract') and source.contract:
            source_contract_name = source.contract.name
        if hasattr(source, 'function') and source.function:
            source_function_name = source.function.name
        
        # If not, try to extract from the operation
        if source_contract_name == "UnknownContract" or source_function_name == "UnknownFunction":
            # Safely get function and contract names from operation
            source_func = source_op.node.function if hasattr(source_op, 'node') and source_op.node else None
            source_contract = source_func.contract if source_func and hasattr(source_func, 'contract') else None
            
            if source_contract and hasattr(source_contract, 'name'):
                source_contract_name = source_contract.name
            if source_func and hasattr(source_func, 'name'):
                source_function_name = source_func.name
        
        # Get contract and function names from sink
        sink_contract_name = "UnknownContract"
        sink_function_name = "UnknownFunction"
        
        # First check if sink.contract and sink.function are directly available
        if hasattr(sink, 'contract') and sink.contract:
            sink_contract_name = sink.contract.name
        if hasattr(sink, 'function') and sink.function:
            sink_function_name = sink.function.name
        
        # If not, try to extract from the operation
        if sink_contract_name == "UnknownContract" or sink_function_name == "UnknownFunction":
            # Safely get function and contract names from operation
            sink_func = sink_op.node.function if hasattr(sink_op, 'node') and sink_op.node else None
            sink_contract = sink_func.contract if sink_func and hasattr(sink_func, 'contract') else None
            
            if sink_contract and hasattr(sink_contract, 'name'):
                sink_contract_name = sink_contract.name
            if sink_func and hasattr(sink_func, 'name'):
                sink_function_name = sink_func.name
        
        result.append(f"## Path #{i}")
        result.append(f"Source: {source.source_type} in {source_contract_name}.{source_function_name}")
        result.append(f"Sink: {sink.sink_type} in {sink_contract_name}.{sink_function_name}")
        result.append("")
        
        result.append("### Operations with Source Code Mapping:")
        for op in operations:
            op_str = str(op)
            node = None
            if isinstance(op, Function):
                node = op.entry_point
            elif isinstance(op, Operation):
                node = op.node

            if not node:
                result.append(f"    IR:  {op_str}")
                result.append("    SRC: No source mapping node available for this operation.")
                result.append("")
                continue
            
            # Default values
            filename = "Unknown File"
            lines_str = "[]"
            source_code_line = "(No direct expression available)"

            # === FIX 2: Use attribute access, not dict.get() ===
            if hasattr(node, 'source_mapping') and node.source_mapping:
                source_map = node.source_mapping
                
                # The .expression attribute is the best source for a clean line
                if hasattr(node, 'expression') and node.expression:
                    source_code_line = str(node.expression).strip().replace('\n', ' ')

                if hasattr(source_map, 'filename') and source_map.filename and hasattr(source_map.filename, 'relative'):
                    filename = source_map.filename.relative
                
                if hasattr(source_map, 'lines'):
                    lines_str = str(source_map.lines)

            result.append(f"    IR:  {op_str}")
            result.append(f"    SRC: File '{filename}', Lines {lines_str}")
            result.append(f"    LNE: {source_code_line}")
            result.append("")
        
        result.append("-" * 40)
        result.append("")
    
    return "\n".join(result)


def map_operation_to_source_location(operation: Operation, source_code: Union[str, Dict[str, str]]) -> str:
    """
    Map a SlitherIR operation to its source code location using Slither's source mappings.
    
    Uses the official Slither method for source mapping:
    1. Operation -> Node: Every SlithIR Operation object has a .node attribute
    2. Node -> Source: Every Node object has a .source_mapping attribute
    
    Args:
        operation: The SlitherIR operation
        source_code: The source code of the contract
        
    Returns:
        A string describing the source code location
    """
    # Step 1: Operation -> Node
    node = operation.node if hasattr(operation, "node") else None
    
    if not node:
        return f"No source mapping available for operation: {operation}"
    
    # Step 2: Node -> Source
    source_map = node.source_mapping if hasattr(node, "source_mapping") else None
    
    if not source_map:
        return f"No source mapping available for node of operation: {operation}"
    
    # Extract information from the source mapping
    filename = source_map.get('filename_relative', 'Unknown') if isinstance(source_map, dict) else (
        source_map.filename.relative if hasattr(source_map, 'filename') and hasattr(source_map.filename, 'relative') else 'Unknown'
    )
    
    lines = source_map.get('lines', ['Unknown']) if isinstance(source_map, dict) else (
        source_map.lines if hasattr(source_map, 'lines') else ['Unknown']
    )
    
    # Extract function and contract information
    function_name = node.function.name if hasattr(node, 'function') and node.function else 'Unknown'
    contract_name = node.function.contract.name if (hasattr(node, 'function') and 
                                                  node.function and 
                                                  hasattr(node.function, 'contract') and 
                                                  node.function.contract) else 'Unknown'
    
    # Extract node type
    node_type = node.type if hasattr(node, 'type') else 'Unknown'
    
    # Extract expression if available (often the cleanest source representation)
    expression = str(node.expression).strip().replace('\n', ' ') if hasattr(node, 'expression') and node.expression else 'No direct expression'
    
    # Build a detailed source location string
    location = f"Contract: {contract_name}, Function: {function_name}, File: {filename}, Lines: {lines}"
    location += f"\nNode Type: {node_type}, Expression: {expression}"
    location += f"\nOperation: {operation}"
    
    return location


def get_source_snippet_for_operation(operation: Operation, source_code: Union[str, Dict[str, str]]) -> str:
    """
    Get a source code snippet for a SlitherIR operation using Slither's source mappings.
    
    Uses the official Slither method for source mapping:
    1. Operation -> Node: Every SlithIR Operation object has a .node attribute
    2. Node -> Source: Every Node object has a .source_mapping and .expression attributes
    
    Args:
        operation: The SlitherIR operation
        source_code: The source code of the contract
        
    Returns:
        A string containing the source code snippet, or empty string if not available
    """
    # Step 1: Operation -> Node
    node = operation.node if hasattr(operation, "node") else None
    
    if not node:
        return ""
    
    # Step 2: Node -> Source
    source_map = node.source_mapping if hasattr(node, "source_mapping") else None
    
    if not source_map:
        return ""
    
    # The .expression attribute often gives the cleanest source representation
    if hasattr(node, 'expression') and node.expression:
        source_code_line = str(node.expression).strip().replace('\n', ' ')
        return source_code_line
    
    # If no expression is available, try to extract from source code
    context_lines = 3  # Number of lines to show before and after the target line
    
    # Extract filename and line information
    filename = None
    line_number = None
    
    if isinstance(source_map, dict):
        filename = source_map.get('filename_relative')
        lines = source_map.get('lines', [])
        if lines:
            line_number = lines[0]
    else:
        if hasattr(source_map, 'filename') and source_map.filename:
            filename = source_map.filename.relative if hasattr(source_map.filename, 'relative') else str(source_map.filename)
        if hasattr(source_map, 'lines') and source_map.lines:
            line_number = source_map.lines[0]
    
    if not filename or not line_number:
        return ""
    
    # Extract start and end positions if available
    start_pos = None
    end_pos = None
    
    if isinstance(source_map, dict):
        start_pos = source_map.get('starting_column')
        end_pos = source_map.get('ending_column')
    else:
        if hasattr(source_map, 'starting_column'):
            start_pos = source_map.starting_column
        if hasattr(source_map, 'ending_column'):
            end_pos = source_map.ending_column
    
    # If source_code is a dictionary, try to find the file in it
    if isinstance(source_code, dict):
        # First try exact match with absolute paths
        if filename in source_code:
            return extract_source_code_snippet_from_string(source_code[filename], line_number, context_lines, start_pos, end_pos)
        
        # Then try to find by filename component
        for path, content in source_code.items():
            # Check if the path ends with the filename
            if path.endswith(filename):
                return extract_source_code_snippet_from_string(content, line_number, context_lines, start_pos, end_pos)
        
        # Last resort: check if filename is contained anywhere in the path
        for path, content in source_code.items():
            if filename in path:
                return extract_source_code_snippet_from_string(content, line_number, context_lines, start_pos, end_pos)
    
    # If source_code is a string, try to extract from it directly
    if isinstance(source_code, str):
        return extract_source_code_snippet_from_string(source_code, line_number, context_lines, start_pos, end_pos)
    
    # Otherwise, try to read the file directly
    try:
        return extract_source_code_snippet(filename, line_number, context_lines, start_pos, end_pos)
    except Exception as e:
        return f"Error extracting source code: {str(e)}"

def extract_source_code_snippet_from_string(
    source: str, 
    line_number: int, 
    context_lines: int = 2, 
    start_pos: Optional[int] = None, 
    end_pos: Optional[int] = None
) -> str:
    """
    Extract a snippet of source code around a specific line from a string,
    with optional highlighting of a specific range within the line.
    
    Args:
        source: Source code as a string
        line_number: Line number to extract
        context_lines: Number of lines of context to include before and after
        start_pos: Starting column position to highlight (optional)
        end_pos: Ending column position to highlight (optional)
        
    Returns:
        A string containing the source code snippet with highlighting
    """
    lines = source.splitlines()
    
    # Ensure line_number is within bounds
    if line_number <= 0 or line_number > len(lines):
        return f"Line number {line_number} out of bounds (1-{len(lines)})"
    
    start_line = max(0, line_number - context_lines - 1)
    end_line = min(len(lines), line_number + context_lines)
    
    snippet = []
    for i in range(start_line, end_line):
        prefix = ">" if i == line_number - 1 else " "
        
        # If this is the target line and we have position information, highlight the specific part
        if i == line_number - 1 and start_pos is not None and end_pos is not None:
            line = lines[i]
            # Ensure positions are within bounds
            start_pos = max(0, min(start_pos, len(line)))
            end_pos = max(0, min(end_pos, len(line)))
            
            # Add the line with highlighting markers
            highlighted_line = (
                line[:start_pos] + 
                "«" + line[start_pos:end_pos] + "»" + 
                line[end_pos:]
            )
            snippet.append(f"{prefix} {i+1}: {highlighted_line}")
        else:
            snippet.append(f"{prefix} {i+1}: {lines[i]}")
    
    return "\n".join(snippet)

def extract_source_code_snippet(
    file_path: str, 
    line_number: int, 
    context_lines: int = 2, 
    start_pos: Optional[int] = None, 
    end_pos: Optional[int] = None
) -> str:
    """
    Extract a snippet of source code around a specific line from a file,
    with optional highlighting of a specific range within the line.
    
    Args:
        file_path: Path to the source code file
        line_number: Line number to extract
        context_lines: Number of lines of context to include before and after
        start_pos: Starting column position to highlight (optional)
        end_pos: Ending column position to highlight (optional)
        
    Returns:
        A string containing the source code snippet with highlighting
    """
    try:
        with open(file_path, "r") as f:
            source = f.read()
        
        return extract_source_code_snippet_from_string(
            source, line_number, context_lines, start_pos, end_pos
        )
    except Exception as e:
        return f"Error extracting source code from {file_path}: {str(e)}"


def map_slither_ir_to_source(ir_operation: Operation, source_code: Union[str, Dict[str, str]]) -> str:
    """
    Map a SlitherIR operation to its source code representation using Slither's official APIs.
    
    Uses the official Slither method for source mapping:
    1. Operation -> Node: Every SlithIR Operation object has a .node attribute
    2. Node -> Source: Every Node object has a .source_mapping and .expression attributes
    
    Args:
        ir_operation: The SlitherIR operation
        source_code: The source code of the contract
        
    Returns:
        A string containing the source code representation
    """
    # Step 1: Operation -> Node
    node = ir_operation.node if hasattr(ir_operation, "node") else None
    
    if not node:
        return f"No source mapping available for operation: {ir_operation}"
    
    # Step 2: Node -> Source
    source_map = node.source_mapping if hasattr(node, "source_mapping") else None
    
    if not source_map:
        return f"No source mapping available for node of operation: {ir_operation}"
    
    # Get source mapping details from the node
    filename = None
    lines = None
    
    if isinstance(source_map, dict):
        filename = source_map.get('filename_relative', 'Unknown')
        lines = source_map.get('lines', ['Unknown'])
    else:
        if hasattr(source_map, 'filename') and source_map.filename:
            filename = source_map.filename.relative if hasattr(source_map.filename, 'relative') else str(source_map.filename)
        if hasattr(source_map, 'lines'):
            lines = source_map.lines
    
    # The .expression attribute often gives the cleanest source representation
    if hasattr(node, 'expression') and node.expression:
        source_code_line = str(node.expression).strip().replace('\n', ' ')
    else:
        # Fallback if there's no high-level expression
        source_code_line = f"(No direct expression for node type: {node.type if hasattr(node, 'type') else 'Unknown'})"
    
    result = f"    IR:  {ir_operation}\n"
    result += f"    SRC: File '{filename}', Lines {lines}\n"
    result += f"    LNE: {source_code_line}"
    
    return result


def map_ir_to_source(slither):
    """
    Iterates through all functions and maps their SlithIR operations
    back to the original source code using Slither's official APIs.
    
    Args:
        slither: An initialized Slither object
        
    Returns:
        None (prints the mapping to stdout)
    """
    for contract in slither.contracts:
        print(f"\n[+] Contract: {contract.name}")
        for function in contract.functions:
            if not function.is_implemented:
                continue

            print(f"  [>] Function: {function.name}")
            
            # function.slithir_operations is a flat list of all IR ops in the function
            for ir_op in function.slithir_operations:
                node = ir_op.node
                
                # Get source mapping details from the node
                source_map = node.source_mapping
                filename = source_map.get('filename_relative', 'Unknown')
                lines = source_map.get('lines', ['Unknown'])

                # The .expression attribute often gives the cleanest source representation
                if hasattr(node, 'expression') and node.expression:
                    source_code_line = str(node.expression).strip().replace('\n', ' ')
                else:
                    # Fallback if there's no high-level expression
                    source_code_line = f"(No direct expression for node type: {node.type if hasattr(node, 'type') else 'Unknown'})"

                print(f"    IR:  {ir_op}")
                print(f"    SRC: File '{filename}', Lines {lines}")
                print(f"    LNE: {source_code_line}\n")
