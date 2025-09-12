from typing import Optional

from slither.core.cfg.node import Node
from slither.slithir.operations import Operation
from slither.core.variables import Variable


class TaintSink:
    """
    A taint sink is a state-changing operation that transfers valuable assets
    (e.g., ETH, ERC-20 tokens) to an address controlled by the non-owner transaction caller,
    where either:
    1. The amount of the assets being transferred is a tainted value.
    2. The execution of the transfer depends on a tainted value.
    """
    
    def __init__(
        self,
        node: Node,
        operation: Operation,
        sink_type: str,
        tainted_variable: Optional[Variable] = None
    ):
        """
        Args:
            node: The CFG node containing the sink operation
            operation: The operation that constitutes a sink
            sink_type: Type of taint sink (e.g., "tainted_value_transfer", "tainted_control_flow_transfer")
            tainted_variable: The tainted variable used in the sink operation (if applicable)
        """
        self.node = node
        self.operation = operation
        self.sink_type = sink_type
        self.tainted_variable = tainted_variable
        self.function = node.function if node else None
        self.contract = node.function.contract if node and node.function else None
    
    def __str__(self) -> str:
        """String representation of the taint sink."""
        contract_name = self.contract.name if self.contract else "Unknown"
        function_name = self.function.name if self.function else "Unknown"
        
        return (
            f"TaintSink(type={self.sink_type}, "
            f"contract={contract_name}, "
            f"function={function_name}, "
            f"operation={self.operation}, "
            f"tainted_variable={self.tainted_variable})"
        )
    
    def to_dict(self) -> dict:
        """Convert to dictionary for serialization."""
        return {
            "sink_type": self.sink_type,
            "contract": self.contract.name if self.contract else "Unknown",
            "function": self.function.name if self.function else "Unknown",
            "node_id": self.node.node_id if self.node else None,
            "operation": str(self.operation),
            "tainted_variable": str(self.tainted_variable) if self.tainted_variable else None
        }
    
    def __eq__(self, other) -> bool:
        """
        Compare two TaintSink objects based on their content.
        Two sinks are equal if they have the same node, operation, sink_type,
        and tainted variable.
        """
        if not isinstance(other, TaintSink):
            return False
        
        # Compare node IDs instead of node objects
        same_node = (self.node.node_id if self.node else None) == (other.node.node_id if other.node else None)
        
        # Compare operation string representations
        same_operation = str(self.operation) == str(other.operation)
        
        # Compare sink types
        same_sink_type = self.sink_type == other.sink_type
        
        # Compare tainted variables
        same_tainted_var = (str(self.tainted_variable) if self.tainted_variable else None) == \
                          (str(other.tainted_variable) if other.tainted_variable else None)
        
        return same_node and same_operation and same_sink_type and same_tainted_var
    
    def __hash__(self) -> int:
        """
        Generate a hash based on the object's content for use in sets and as dict keys.
        This must be consistent with the __eq__ method.
        """
        # Create a tuple of hashable components
        hashable = (
            self.node.node_id if self.node else None,
            str(self.operation),
            self.sink_type,
            str(self.tainted_variable) if self.tainted_variable else None
        )
        
        return hash(hashable)
