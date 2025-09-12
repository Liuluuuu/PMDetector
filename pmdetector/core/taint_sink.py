from typing import Optional

from slither.core.cfg.node import Node
from slither.slithir.operations import Operation
from slither.core.variables import Variable


class TaintSink:
    def __init__(
        self,
        node: Node,
        operation: Operation,
        sink_type: str,
        tainted_variable: Optional[Variable] = None
    ):
        self.node = node
        self.operation = operation
        self.sink_type = sink_type
        self.tainted_variable = tainted_variable
        self.function = node.function if node else None
        self.contract = node.function.contract if node and node.function else None
    
    def __str__(self) -> str:

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
        return {
            "sink_type": self.sink_type,
            "contract": self.contract.name if self.contract else "Unknown",
            "function": self.function.name if self.function else "Unknown",
            "node_id": self.node.node_id if self.node else None,
            "operation": str(self.operation),
            "tainted_variable": str(self.tainted_variable) if self.tainted_variable else None
        }
    
    def __eq__(self, other) -> bool:
        if not isinstance(other, TaintSink):
            return False
        
        same_node = (self.node.node_id if self.node else None) == (other.node.node_id if other.node else None)
        
        same_operation = str(self.operation) == str(other.operation)
        
        same_sink_type = self.sink_type == other.sink_type

        same_tainted_var = (str(self.tainted_variable) if self.tainted_variable else None) == \
                          (str(other.tainted_variable) if other.tainted_variable else None)
        
        return same_node and same_operation and same_sink_type and same_tainted_var
    
    def __hash__(self) -> int:
        hashable = (
            self.node.node_id if self.node else None,
            str(self.operation),
            self.sink_type,
            str(self.tainted_variable) if self.tainted_variable else None
        )
        
        return hash(hashable)
