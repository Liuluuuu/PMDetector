from typing import Dict
from pmdetector.core.taint_result import TaintResult
from slither.slithir.operations import Operation
from slither.core.declarations import Function


def taint_result_to_source_text(taint_result: TaintResult, source_code: Dict[str, str], verbose: bool = False) -> str:
    """Maps taint paths to source code using Slither's source mappings."""
    result = []
    result.append("# Taint Analysis Results with Source Code Mapping")
    result.append(f"Found {len(taint_result.paths)} tainted paths.")
    result.append("")
    
    if not taint_result.paths:
        result.append("No relevant paths found in the taint analysis.")
        return "\n".join(result)
    
    for i, (source, sink, operations) in enumerate(taint_result.paths, 1):
        source_op = source.operation
        sink_op = sink.operation
        
        source_contract_name = "UnknownContract"
        source_function_name = "UnknownFunction"
  
        if hasattr(source, 'contract') and source.contract:
            source_contract_name = source.contract.name
        if hasattr(source, 'function') and source.function:
            source_function_name = source.function.name

        if source_contract_name == "UnknownContract" or source_function_name == "UnknownFunction":
            source_func = source_op.node.function if hasattr(source_op, 'node') and source_op.node else None
            source_contract = source_func.contract if source_func and hasattr(source_func, 'contract') else None
            
            if source_contract and hasattr(source_contract, 'name'):
                source_contract_name = source_contract.name
            if source_func and hasattr(source_func, 'name'):
                source_function_name = source_func.name
        
        sink_contract_name = "UnknownContract"
        sink_function_name = "UnknownFunction"

        if hasattr(sink, 'contract') and sink.contract:
            sink_contract_name = sink.contract.name
        if hasattr(sink, 'function') and sink.function:
            sink_function_name = sink.function.name
        
        if sink_contract_name == "UnknownContract" or sink_function_name == "UnknownFunction":
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
            
            filename = "Unknown File"
            lines_str = "[]"
            source_code_line = "(No direct expression available)"

            if hasattr(node, 'source_mapping') and node.source_mapping:
                source_map = node.source_mapping
                
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
