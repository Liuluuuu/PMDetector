from typing import Set, Optional, Union

from slither.core.cfg.node import Node
from slither.slithir.operations import Operation
from slither.core.variables import Variable
from slither.core.declarations import Function


class TaintSource:
    """
    A taint source represents external inputs that can introduce tainted data.
    This includes:
    1. Externally-supplied contract addresses
    2. Return values from external function calls
    3. Other external inputs like block.timestamp, msg.sender, etc.
    """
    
    def __init__(
        self,
        node: Node,
        operation: Operation,
        tainted_variables: Set,
        source_type: str
    ):
        """
        Initialize a taint source.
        
        Args:
            node: The CFG node containing the source operation
            operation: The operation that introduces taint
            tainted_variables: Set of variables tainted by this source
            source_type: Type of taint source (e.g., "external_call")
        """
        self.node = node
        self.operation = operation
        self.tainted_variables = tainted_variables
        self.source_type = source_type
        self.function = node.function if node else None
        self.contract = node.function.contract if node and node.function else None
    
    def __str__(self) -> str:
        """String representation of the taint source."""
        contract_name = self.contract.name if self.contract else "Unknown"
        function_name = self.function.name if self.function else "Unknown"
        
        return (
            f"TaintSource(type={self.source_type}, "
            f"contract={contract_name}, "
            f"function={function_name}, "
            f"operation={self.operation})"
        )
    
    def to_dict(self) -> dict:
        """Convert to dictionary for serialization."""
        return {
            "source_type": self.source_type,
            "contract": self.contract.name if self.contract else "Unknown",
            "function": self.function.name if self.function else "Unknown",
            "node_id": self.node.node_id if self.node else None,
            "operation": str(self.operation),
            "tainted_variables": [str(v) for v in self.tainted_variables]
        }
    
    def __eq__(self, other) -> bool:
        """
        Compare two TaintSource objects based on their content.
        Two sources are equal if they have the same node, operation, source_type,
        and tainted variables.
        """
        if not isinstance(other, TaintSource):
            return False
        
        # Compare node IDs instead of node objects
        same_node = (self.node.node_id if self.node else None) == (other.node.node_id if other.node else None)
        
        # Compare operation string representations
        same_operation = str(self.operation) == str(other.operation)
        
        # Compare source types
        same_source_type = self.source_type == other.source_type
        
        # Compare tainted variables as sets of their string representations
        self_vars = {str(v) for v in self.tainted_variables}
        other_vars = {str(v) for v in other.tainted_variables}
        same_tainted_vars = self_vars == other_vars
        
        return same_node and same_operation and same_source_type and same_tainted_vars
    
    def __hash__(self) -> int:
        """
        Generate a hash based on the object's content for use in sets and as dict keys.
        This must be consistent with the __eq__ method.
        """
        # Use frozenset for tainted variables to make them hashable
        tainted_vars_hash = frozenset(str(v) for v in self.tainted_variables)
        
        # Create a tuple of hashable components
        hashable = (
            self.node.node_id if self.node else None,
            str(self.operation),
            self.source_type,
            tainted_vars_hash
        )
        
        return hash(hashable)
