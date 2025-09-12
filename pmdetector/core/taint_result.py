"""
Taint result module for the PMDetector taint analysis tool.
"""

import json
from typing import Dict, List, Tuple

from slither.slithir.operations import Operation

from pmdetector.core.taint_source import TaintSource
from pmdetector.core.taint_sink import TaintSink


class TaintResult:
    """
    Represents the results of a taint analysis.

    """  
    def __init__(
        self,
        sources: List[TaintSource],
        sinks: List[TaintSink],
        paths: List[Tuple[TaintSource, TaintSink, List[Operation]]],
        unfiltered_path_count: int = 0
    ):
        """
        Initialize a TaintResult object.
        
        Args:
            sources: List of taint sources
            sinks: List of taint sinks
            paths: List of tainted paths, each containing a source, sink, and list of operations
            unfiltered_path_count: Total number of paths before filtering (default: 0)
        """
        self.sources = sources or []
        self.sinks = sinks or []
        self.paths = paths or []
        self.unfiltered_path_count = unfiltered_path_count
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            "sources": [source.to_dict() for source in self.sources],
            "sinks": [sink.to_dict() for sink in self.sinks],
            "paths": [
                {
                    "source": source.to_dict(),
                    "sink": sink.to_dict(),
                    "operations": [str(op) for op in path]
                }
                for source, sink, path in self.paths
            ],
            "unfiltered_path_count": self.unfiltered_path_count
        }
    
    def to_json(self) -> str:
        """Convert to JSON string."""
        return json.dumps(self.to_dict(), indent=2)
    
    def to_text(self) -> str:
        """Convert to human-readable text format."""
        result = []
        
        # Summary
        result.append("=== PMDetector Taint Analysis Results ===")
        result.append(f"Found {len(self.sources)} taint sources")
        result.append(f"Found {len(self.sinks)} taint sinks")
        result.append(f"Found {len(self.paths)} tainted paths (filtered from {self.unfiltered_path_count} total potential paths)")
        result.append(f"Path filtering efficiency: {(self.unfiltered_path_count - len(self.paths)) / self.unfiltered_path_count * 100:.2f}% of paths filtered" if self.unfiltered_path_count > 0 else "No paths to filter")
        result.append("")
        
        # Sources
        if self.sources:
            result.append("=== Taint Sources ===")
            for i, source in enumerate(self.sources, 1):
                contract_name = source.contract.name if source.contract else "Unknown"
                function_name = source.function.name if source.function else "Unknown"
                result.append(f"Source #{i}: {source.source_type}")
                result.append(f"  Contract: {contract_name}")
                result.append(f"  Function: {function_name}")
                result.append(f"  Operation: {source.operation}")
                result.append(f"  Tainted Variables: {', '.join(str(v) for v in source.tainted_variables)}")
                result.append("")
        
        # Sinks
        if self.sinks:
            result.append("=== Taint Sinks ===")
            for i, sink in enumerate(self.sinks, 1):
                contract_name = sink.contract.name if sink.contract else "Unknown"
                function_name = sink.function.name if sink.function else "Unknown"
                result.append(f"Sink #{i}: {sink.sink_type}")
                result.append(f"  Contract: {contract_name}")
                result.append(f"  Function: {function_name}")
                result.append(f"  Operation: {sink.operation}")
                if sink.tainted_variable:
                    result.append(f"  Tainted Variable: {sink.tainted_variable}")
                result.append("")
        
        # Paths
        if self.paths:
            result.append("=== Tainted Paths ===")
            for i, (source, sink, path) in enumerate(self.paths, 1):
                source_contract = source.contract.name if source.contract else "Unknown"
                source_function = source.function.name if source.function else "Unknown"
                sink_contract = sink.contract.name if sink.contract else "Unknown"
                sink_function = sink.function.name if sink.function else "Unknown"
                
                result.append(f"Path #{i}:")
                result.append(f"  Source: {source.source_type} in {source_contract}.{source_function}")
                result.append(f"  Sink: {sink.sink_type} in {sink_contract}.{sink_function}")
                result.append("  Path Operations:")
                for j, op in enumerate(path, 1):
                    result.append(f"    {j}. {op}")
                result.append("")
        
        return "\n".join(result)
    
    def has_vulnerabilities(self) -> bool:
        """Check if any vulnerabilities were found."""
        return len(self.paths) > 0
