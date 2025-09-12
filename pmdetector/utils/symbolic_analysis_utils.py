"""
Symbolic analysis utilities for computing storage slots in Solidity contracts.
"""

from typing import Any, Dict, Optional, Union
import hashlib
from slither.core.variables import StateVariable
from slither.core.variables.state_variable import StateVariable
from slither.core.declarations.structure import Structure
from slither.core.expressions import IndexAccess, MemberAccess
from slither.slithir.variables import StateIRVariable, ReferenceVariable


def get_base_slot(variable: Union[StateVariable, StateIRVariable, IndexAccess, MemberAccess, object]) -> int:
    """
    Determine the base storage slot for a state variable.
    """
    if isinstance(variable, (IndexAccess, MemberAccess)):
        if isinstance(variable, IndexAccess):
            base_var = variable.expression_left
            return get_base_slot(base_var)
        elif isinstance(variable, MemberAccess):
            base_var = variable.expression
            return get_base_slot(base_var)
    
    if isinstance(variable, StateIRVariable):
        variable = variable.state_variable
    
    if isinstance(variable, StateVariable):
        if hasattr(variable, "storage_slot") and variable.storage_slot is not None:
            return variable.storage_slot
        
        # If the storage_slot attribute is not available, compute it based on declaration order
        contract = variable.contract
        state_variables = [v for v in contract.state_variables if not v.is_constant]
        
        current_slot = 0
        current_offset = 0
        
        for var in state_variables:
            if var == variable:
                return current_slot
            
            # Skip constant variables as they don't take up storage
            if var.is_constant:
                continue

            var_size = _get_variable_size(var)
            
            # Check if this variable needs a new slot
            if current_offset + var_size > 32:
                current_slot += 1
                current_offset = 0
            
            current_offset += var_size

            if current_offset == 32:
                current_slot += 1
                current_offset = 0  
        return 0  
    return f"slot({variable})"


def compute_mapping_slot(key: object, base_slot: Union[int, str]) -> str:
    """
    Compute the storage slot for a mapping element using keccak256(key, base_slot).
    """
    return f"keccak256({key}, {base_slot})"


def compute_array_slot(index: object, base_slot: Union[int, str]) -> str:
    """
    Compute the storage slot for an array element using keccak256(base_slot) + index.
    """
    return f"keccak256({base_slot}) + {index}"


def is_packed_variable(variable: StateVariable) -> bool:
    """
    Check if a variable is packed with other variables in the same storage slot.
    
    Args:
        variable: The state variable to check
        
    Returns:
        True if the variable shares a slot with other variables, False otherwise
    """
    if not isinstance(variable, StateVariable):
        return False
    
    # Get all state variables in the contract
    contract = variable.contract
    state_variables = [v for v in contract.state_variables if not v.is_constant]
    
    # Find the position of our variable
    try:
        var_index = state_variables.index(variable)
    except ValueError:
        return False
    
    # Check if the previous variable is in the same slot
    if var_index > 0:
        prev_var = state_variables[var_index - 1]
        prev_slot = get_base_slot(prev_var)
        curr_slot = get_base_slot(variable)
        
        if prev_slot == curr_slot:
            return True
    
    # Check if the next variable is in the same slot
    if var_index < len(state_variables) - 1:
        next_var = state_variables[var_index + 1]
        curr_slot = get_base_slot(variable)
        next_slot = get_base_slot(next_var)
        
        if curr_slot == next_slot:
            return True
    
    return False


def get_slot_for_struct_member(struct_var: Union[StateVariable, MemberAccess, object], 
                              member_name: str, 
                              base_slot: Union[int, str]) -> Union[int, str]:
    """
    Compute the storage slot for a struct member.
    """
    struct_type = None
    
    if isinstance(struct_var, StateVariable):
        struct_type = struct_var.type
    elif isinstance(struct_var, MemberAccess):
        if hasattr(struct_var.expression, "type"):
            struct_type = struct_var.expression.type
    
    if struct_type is None or not hasattr(struct_type, "members"):
        # If we can't determine the struct type, return a symbolic representation
        return f"{base_slot} + offset({member_name})"
    
    members = struct_type.members
    
    current_offset = 0
    for member in members:
        if member.name == member_name:
            slot_offset = current_offset // 32
            return f"{base_slot} + {slot_offset}"

        member_size = _get_variable_size(member)
        current_offset += member_size
        
        if current_offset % 32 == 0:
            current_offset = (current_offset // 32) * 32
    
    # If we didn't find the member, return a symbolic representation
    return f"{base_slot} + offset({member_name})"


def _get_variable_size(variable) -> int:
    """
    Get the size in bytes of a variable based on its type.
    """
    if hasattr(variable, "type"):
        type_str = str(variable.type)
        
        # Handle basic types
        if "bool" in type_str:
            return 1
        elif "uint8" in type_str or "int8" in type_str:
            return 1
        elif "uint16" in type_str or "int16" in type_str:
            return 2
        elif "uint24" in type_str or "int24" in type_str:
            return 3
        elif "uint32" in type_str or "int32" in type_str:
            return 4
        elif "uint40" in type_str or "int40" in type_str:
            return 5
        elif "uint48" in type_str or "int48" in type_str:
            return 6
        elif "uint56" in type_str or "int56" in type_str:
            return 7
        elif "uint64" in type_str or "int64" in type_str:
            return 8
        elif "uint72" in type_str or "int72" in type_str:
            return 9
        elif "uint80" in type_str or "int80" in type_str:
            return 10
        elif "uint88" in type_str or "int88" in type_str:
            return 11
        elif "uint96" in type_str or "int96" in type_str:
            return 12
        elif "uint104" in type_str or "int104" in type_str:
            return 13
        elif "uint112" in type_str or "int112" in type_str:
            return 14
        elif "uint120" in type_str or "int120" in type_str:
            return 15
        elif "uint128" in type_str or "int128" in type_str:
            return 16
        elif "uint136" in type_str or "int136" in type_str:
            return 17
        elif "uint144" in type_str or "int144" in type_str:
            return 18
        elif "uint152" in type_str or "int152" in type_str:
            return 19
        elif "uint160" in type_str or "int160" in type_str:
            return 20
        elif "uint168" in type_str or "int168" in type_str:
            return 21
        elif "uint176" in type_str or "int176" in type_str:
            return 22
        elif "uint184" in type_str or "int184" in type_str:
            return 23
        elif "uint192" in type_str or "int192" in type_str:
            return 24
        elif "uint200" in type_str or "int200" in type_str:
            return 25
        elif "uint208" in type_str or "int208" in type_str:
            return 26
        elif "uint216" in type_str or "int216" in type_str:
            return 27
        elif "uint224" in type_str or "int224" in type_str:
            return 28
        elif "uint232" in type_str or "int232" in type_str:
            return 29
        elif "uint240" in type_str or "int240" in type_str:
            return 30
        elif "uint248" in type_str or "int248" in type_str:
            return 31
        elif "uint256" in type_str or "int256" in type_str or "uint" in type_str or "int" in type_str:
            return 32
        elif "address" in type_str:
            return 20
        elif "bytes" in type_str:
            if type_str == "bytes":
                return 32
            elif "bytes" in type_str and len(type_str) > 5:
                size = int(type_str[5:])
                return size
        elif "string" in type_str:
            return 32
        elif "mapping" in type_str:
            return 32
        elif "array" in type_str:
            return 32
        elif "struct" in type_str:
            return 32
    
    # Default to 32 bytes (full slot) for unknown types
    return 32
