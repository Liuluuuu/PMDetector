from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple, Union

from slither import Slither
from slither.slithir.operations import (
    Operation, 
    SolidityCall, 
    LowLevelCall, 
    HighLevelCall,
    InternalCall,
    Return,
    Binary,
    BinaryType,
    Condition,
    Assignment
)

from slither.core.dominators.utils import compute_dominators as slither_compute_dominators

def compute_post_dominator_tree(slither):
    """
    Compute the post-dominator tree for all functions in the Slither object.
    """
    for contract in slither.contracts:
        for function in contract.functions:
            if not (function.is_implemented and function.nodes):
                continue
            
            if hasattr(function.nodes[0], 'immediate_postdominator'):
                continue

            reversed_graph = {node: [] for node in function.nodes}
            for node in function.nodes:
                for son in node.sons:
                    reversed_graph[son].append(node)
            
            exit_nodes = [node for node in function.nodes if not node.sons]
            if not exit_nodes:
                continue

            virtual_exit_node = Node(NodeType.IF, len(function.nodes) + 1, function, [])
            reversed_graph[virtual_exit_node] = []

            for exit_node in exit_nodes:
                reversed_graph[virtual_exit_node].append(exit_node)
            
            entry_for_post_dominance = virtual_exit_node
            
            try:
                dominators = slither_compute_dominators(reversed_graph, entry_for_post_dominance)
            except TypeError as e:
                if "takes 1 positional argument but 2 were given" in str(e):
                    dominators = slither_compute_dominators(reversed_graph)
                else:
                    raise e
            
            if dominators is None:
                print(f"Warning: Dominator computation still failed for function {function.name}.")
                continue
            
            for node in function.nodes:
                post_doms = dominators.get(node, set()) - {node, virtual_exit_node}
                if post_doms:
                    idom = min(post_doms, key=lambda n: len(dominators.get(n, set())))
                    node.immediate_postdominator = idom
                else:
                    node.immediate_postdominator = None

from slither.slithir.variables import (
    StateIRVariable,
    LocalIRVariable,
    TemporaryVariable
)
from slither.core.declarations.solidity_variables import SolidityVariable
from slither.core.variables import StateVariable
from slither.core.expressions import IndexAccess, MemberAccess
from pmdetector.utils.symbolic_analysis_utils import (
    get_base_slot,          
    compute_mapping_slot,   
    compute_array_slot,    
    get_slot_for_struct_member
)
from slither.core.declarations import Function, Contract
from slither.core.cfg.node import Node, NodeType
from slither.analyses.data_dependency.data_dependency import is_dependent

from pmdetector.core.taint_source import TaintSource
from pmdetector.core.taint_sink import TaintSink
from pmdetector.core.taint_result import TaintResult
from pmdetector.utils.blockchain import get_contract_source


class TaintDetector:    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.taint_graph: Dict[Union[LocalIRVariable, TemporaryVariable, StateIRVariable], Tuple[Operation, Union[LocalIRVariable, TemporaryVariable, StateIRVariable]]] = {}
        self.tainted_storage_slots: Dict[Contract, Set[int]] = {}
        self.tainted_control_flow_nodes: Set[Node] = set()
        self.taint_sources: List[TaintSource] = []
        self.taint_sinks: List[TaintSink] = []
        self.taint_paths: List[Tuple[TaintSource, TaintSink, List[Operation]]] = []
        self.tainted_functions: Dict[Function, Set[Union[LocalIRVariable, TemporaryVariable, StateIRVariable]]] = {}
        self.slither: Optional[Slither] = None
        self.total_potential_paths: int = 0  # Total paths before filtering
    
    def analyze_address(self, address: str, blockchain: str = "ethereum") -> TaintResult:
        source_code = get_contract_source(address, blockchain)
        if not source_code:
            raise ValueError(f"Could not retrieve source code for address {address} on {blockchain}")
        
        temp_file = Path(f"temp_{blockchain}_{address}.sol")
        with open(temp_file, "w") as f:
            f.write(source_code)
        
        try:
            result = self.analyze_file(temp_file)
        finally:
            temp_file.unlink()
        
        return result
    
    def analyze_file(self, file_path: Path, solc_path: Optional[str] = None, solc_remaps: Optional[List[str]] = None, solc_include_path: Optional[List[str]] = None) -> TaintResult:
        """
        Perform taint analysis on a Solidity source file.
        """
        try:
            slither_kwargs = {}
            if solc_path:
                slither_kwargs['solc'] = solc_path
            if solc_remaps:
                slither_kwargs['solc_remaps'] = solc_remaps
            if solc_include_path:
                slither_kwargs['solc_include_path'] = solc_include_path
            slither_kwargs['solc_via_ir'] = True

            if not file_path.is_file():
                 raise FileNotFoundError(f"Target path for analysis must be a file: {file_path}")
            
            target_path = str(file_path)
            slither = Slither(target_path, **slither_kwargs)
                
            return self._analyze_slither(slither)
        except Exception as e:
            if self.verbose:
                print(f"Error analyzing {file_path}: {e}")
            raise
    
    def analyze_bytecode(self, bytecode: str) -> TaintResult:
        """
        Analyze contract bytecode.
        """
        temp_file = Path("temp_bytecode.evm")
        with open(temp_file, "w") as f:
            f.write(bytecode)
        
        try:
            slither = Slither(str(temp_file), solc_force_legacy_json=True)
            return self._analyze_slither(slither)
        finally:
            temp_file.unlink()
    
    def _analyze_slither(self, slither: Slither) -> TaintResult:
        self._reset_state()
        self.slither = slither

        compute_post_dominator_tree(slither)
        
        last_taint_source_count = -1
        last_taint_sink_count = -1
        last_tainted_functions_count = -1
        max_iterations = 10
        
        for iteration in range(max_iterations):
            current_source_count = len(self.taint_sources)
            current_sink_count = len(self.taint_sinks)
            current_tainted_functions_count = sum(len(vars) for vars in self.tainted_functions.values())
            
            if (current_source_count == last_taint_source_count and 
                current_sink_count == last_taint_sink_count and
                current_tainted_functions_count == last_tainted_functions_count):
                break
            
            if self.verbose:
                print(f"Starting iteration {iteration+1}")
                print(f"Sources: {current_source_count}, Sinks: {current_sink_count}, Tainted Functions: {current_tainted_functions_count}")
            
            last_taint_source_count = current_source_count
            last_taint_sink_count = current_sink_count
            last_tainted_functions_count = current_tainted_functions_count
            
            for contract in slither.contracts:
                self._analyze_contract(contract)
        
        self._find_taint_paths()
        
        return TaintResult(
            sources=self.taint_sources,
            sinks=self.taint_sinks,
            paths=self.taint_paths,
            unfiltered_path_count=self.total_potential_paths
        )
    
    def _reset_state(self):
        self.taint_graph = {}
        self.tainted_storage_slots = {}
        self.tainted_control_flow_nodes = set()
        self.taint_sources = []
        self.taint_sinks = []
        self.taint_paths = []
        self.tainted_functions = {}
        self.total_potential_paths = 0  
    
    def _analyze_contract(self, contract: Contract):
        """
        Analyze a single contract for taint sources and sinks.
        """
        if contract not in self.tainted_storage_slots:
            self.tainted_storage_slots[contract] = set()
        
        for function in contract.functions:
            if function.is_implemented:
                self._analyze_function(function)
    
    def _analyze_function(self, function: Function):
        """
        Analyze a single function for taint sources and sinks.
        """
        sorted_nodes = sorted(function.nodes, key=lambda n: n.node_id)
        
        for node in sorted_nodes:
            self._identify_taint_sources(node)
            self._propagate_taint(node)
            self._is_control_flow_tainted(node)
            self._identify_taint_sinks(node)
    
    PRICE_ORACLE_FUNCTIONS = {
    "getReserves", "getAmountsOut", "getAmountOut", "getAmountIn", "getAmountsIn",   # Uniswap V2
    "slot0", "observe", "quoteExactInputSingle", "quoteExactInput" # Uniswap V3
    "get_dy", "get_dy_underlying", "get_virtual_price", # Curve Finance
    "latestRoundData", "consult",  "quoteExactInputSingle", "quoteExactInput", # Chainlink and other oracles
    "getCurrentPrice", "getPrice", "getPriceUSD", "getSpotPrice", "getTWAP", # Generic price functions
    "balanceOf", "totalSupply", # Standard Tokens (IERC20)
    "totalAssets", "convertToShares", "convertToAssets", "previewDeposit", "previewRedeem", # Tokenized Vaults (ERC4626)
}

    def _identify_taint_sources(self, node: Node):
        """
        Identify taint sources. 
        """
        sources = []
        function = node.function

        # SOURCE 1: External Economic Data Source - Track return values from external view/pure functions that are used in MUL/DIV operations
        oracle_return_values = set()
        
        for ir in node.irs:
            if isinstance(ir, HighLevelCall) and ir.lvalue:
                # Check if it's a view or pure function
                if hasattr(ir, 'function') and ir.function:
                    is_view = hasattr(ir.function, 'is_view') and ir.function.is_view
                    is_pure = hasattr(ir.function, 'is_pure') and ir.function.is_pure
                    if is_view or is_pure:
                        oracle_return_values.add(ir.lvalue)
                # Fallback for functions without is_view/is_pure attributes
                elif ir.function_name in self.PRICE_ORACLE_FUNCTIONS:
                    oracle_return_values.add(ir.lvalue)
        
        # Check if these return values are used in MUL/DIV operations
        for ir in node.irs:
            if isinstance(ir, Binary) and ir.lvalue and ir.lvalue not in self.taint_graph:
                if ir.type in [BinaryType.MULTIPLICATION, BinaryType.DIVISION]:
                    for operand in [ir.variable_left, ir.variable_right]:
                        if operand in oracle_return_values:
                            self.taint_graph[ir.lvalue] = (ir, operand)
                            source = TaintSource(node=node, operation=ir, tainted_variables={ir.lvalue}, 
                                               source_type="external_economic_data_source")
                            sources.append(source)
                            # Also mark the oracle return value itself as tainted for propagation
                            if operand not in self.taint_graph:
                                for prev_ir in node.irs:
                                    if hasattr(prev_ir, 'lvalue') and prev_ir.lvalue == operand:
                                        self.taint_graph[operand] = (prev_ir, None)
                                        oracle_source = TaintSource(node=node, operation=prev_ir, 
                                                                  tainted_variables={operand}, 
                                                                  source_type="oracle_return_value")
                                        sources.append(oracle_source)
                                        break
        
        # SOURCE 2 : Parameters of any non-view/pure public/external function
        is_view = hasattr(function, 'is_view') and function.is_view
        is_pure = hasattr(function, 'is_pure') and function.is_pure
        if function.visibility in ["public", "external"] and not is_view and not is_pure:
            for param in function.parameters:
                if node == function.entry_point and param not in self.taint_graph:
                    self.taint_graph[param] = (function, None) 
                    source = TaintSource(node=node, operation=function, tainted_variables={param}, 
                                         source_type="external_input_params")
                    sources.append(source)
        
        # SOURCE 3 : Blockchain States including msg.sender and msg.value
        if function.visibility in ["public", "external"] and not is_view and not is_pure:
            for ir in node.irs:
                if isinstance(ir, Assignment):
                    read_var = ir.rvalue
                    if isinstance(read_var, SolidityVariable) and read_var.name in ["msg.sender", "msg.value"]:
                        if ir.lvalue and ir.lvalue not in self.taint_graph:
                            self.taint_graph[ir.lvalue] = (ir, read_var) 
                            source = TaintSource(node=node, operation=ir, tainted_variables={ir.lvalue}, 
                                                 source_type=read_var.name)
                            sources.append(source)

        for source in sources:
            if source not in self.taint_sources:
                self.taint_sources.append(source)
    
    def _propagate_taint(self, node: Node):
        """
        Propagate taint through operations in a node and build the taint_graph.
        """
        if self.verbose:
            print(f"Processing function {node.function.name}, node {node.node_id}")
            print(f"Current taint graph size: {len(self.taint_graph)}")
        
        for ir in node.irs:
            
            # Rule 1: Data Flow Propagation - Including Assignment, Binary, Index, Member, SolidityCall, Unpack etc.
            if hasattr(ir, 'lvalue') and ir.lvalue and hasattr(ir, 'read'):
                if ir.lvalue not in self.taint_graph:
                    for read_var in ir.read:
                        if read_var is not None and read_var in self.taint_graph:
                            # Propagate taint: lvalue is tainted because of read_var
                            self.taint_graph[ir.lvalue] = (ir, read_var)
                            if self.verbose:
                                print(f"Taint propagated from {read_var} to {ir.lvalue} via {ir}")
                            break
            
            # Handle internal function calls
            if isinstance(ir, InternalCall):
                if hasattr(ir, 'function'):
                    if self.verbose:
                        print(f"Found internal call to {ir.function.name} in {node.function.name} at node {node.node_id}")
                    
                    if hasattr(ir, 'arguments') and ir.arguments:
                        for i, arg in enumerate(ir.arguments):
                            if arg is not None and arg in self.taint_graph:
                                if hasattr(ir.function, 'parameters') and i < len(ir.function.parameters):
                                    param = ir.function.parameters[i]

                                if param not in self.taint_graph:
                                    self.taint_graph[param] = (ir, arg)

                    # Handle return values from tainted functions (existing logic)
                    if ir.lvalue and ir.function in self.tainted_functions and ir.lvalue not in self.taint_graph:
                        tainted_return_vars = self.tainted_functions[ir.function]
                        
                        if tainted_return_vars:
                            tainted_var = next(iter(tainted_return_vars))
                            self.taint_graph[ir.lvalue] = (ir, tainted_var)
                            
                            if self.verbose:
                                print(f"Linking return value {ir.lvalue} to tainted variable {tainted_var} from function {ir.function.name}")

                                caller_func = node.function.name
                                callee_func = ir.function.name
                                caller_contract = node.function.contract.name if hasattr(node.function, 'contract') else "unknown"
                                callee_contract = ir.function.contract.name if hasattr(ir.function, 'contract') else "unknown"
                                print(f"Inter-procedural taint: {caller_contract}.{caller_func} calls {callee_contract}.{callee_func}")
            
            # Rule 2: Persistent State Poisoning (SSTORE)
            if isinstance(ir, Assignment) and isinstance(ir.lvalue, (StateVariable, StateIRVariable, IndexAccess, MemberAccess)):
                for read_var in ir.read:
                    if read_var is not None and read_var in self.taint_graph:
                        lvalue = ir.lvalue
                        contract = node.function.contract
                        
                        if isinstance(lvalue, (StateVariable, StateIRVariable)):
                            slot = get_base_slot(lvalue)         
                        elif isinstance(lvalue, IndexAccess): 
                            base_var = lvalue.base_variable
                            index_expr = lvalue.index_expression
                            base_slot = get_base_slot(base_var)

                            if base_var.is_mapping:
                                slot = compute_mapping_slot(index_expr, base_slot)
                            else: # It's an array
                                slot = compute_array_slot(index_expr, base_slot)
                        elif isinstance(lvalue, MemberAccess):
                            struct_var = lvalue.struct
                            member_name = lvalue.member_name
                            base_slot = get_base_slot(struct_var)
                            slot = get_slot_for_struct_member(struct_var, member_name, base_slot)
                        
                        if contract in self.tainted_storage_slots:
                           self.tainted_storage_slots[contract].add(slot)
                        break
            
            # Rule 3: Persistent State Propagation (SLOAD)
            if isinstance(ir, Assignment) and ir.lvalue and ir.lvalue not in self.taint_graph:
                for read_var in ir.read:
                    if read_var is not None and isinstance(read_var, (StateVariable, StateIRVariable)):
                        contract = node.function.contract
                        if contract in self.tainted_storage_slots:
                            slot = get_base_slot(read_var)
                            if slot in self.tainted_storage_slots[contract]:
                                self.taint_graph[ir.lvalue] = (ir, read_var)
                                if self.verbose:
                                    print(f"Taint propagated from storage slot {slot} to {ir.lvalue}")
                                break
                    
                    elif read_var is not None and isinstance(read_var, IndexAccess):
                        base_var = read_var.expression_left if hasattr(read_var, 'expression_left') else None
                        index_expr = read_var.index_expression if hasattr(read_var, 'index_expression') else None
                        
                        if base_var and index_expr:
                            contract = node.function.contract
                            if contract in self.tainted_storage_slots:
                                base_slot = get_base_slot(base_var)

                                if base_var.is_mapping:
                                    slot = compute_mapping_slot(index_expr, base_slot)
                                else: 
                                    slot = compute_array_slot(index_expr, base_slot)
                                
                                if slot in self.tainted_storage_slots[contract]:
                                    # Propagate taint from storage
                                    self.taint_graph[ir.lvalue] = (ir, read_var)
                                    if self.verbose:
                                        print(f"Taint propagated from mapping/array slot {slot} to {ir.lvalue}")
                                    break
                    
                    elif read_var is not None and isinstance(read_var, MemberAccess):
                        struct_var = read_var.struct if hasattr(read_var, 'struct') else None
                        member_name = read_var.member_name if hasattr(read_var, 'member_name') else None
                        
                        if struct_var and member_name:
                            contract = node.function.contract
                            if contract in self.tainted_storage_slots:
                                base_slot = get_base_slot(struct_var)
                                slot = get_slot_for_struct_member(struct_var, member_name, base_slot)
                                
                                if slot in self.tainted_storage_slots[contract]:
                                    # Propagate taint from storage
                                    self.taint_graph[ir.lvalue] = (ir, read_var)
                                    if self.verbose:
                                        print(f"Taint propagated from struct member slot {slot} to {ir.lvalue}")
                                    break
            
            # Check for Return statements with tainted values
            if isinstance(ir, Return):
                for v in ir.values:
                    if v is not None and v in self.taint_graph:
                        if node.function not in self.tainted_functions:
                            self.tainted_functions[node.function] = set()
                        
                        self.tainted_functions[node.function].add(v)
    
    TRANSFER_KEYWORDS = {'transfer', 'send', 'payout', 'withdraw', 'deposit', 'move'}
       
    def _is_control_flow_tainted(self, node: Node) -> None:
        """
        Check if a node's control flow is tainted and mark dependent nodes.
        Include if, require, assert statements. 
        """
        if node.contains_if() or node.contains_require_or_assert():
            if self.verbose:
                print(f"Checking control flow taint for node {node.node_id} in function {node.function.name}")
                print(f"Node contains: {node.irs}")
            
            for ir in node.irs:
                tainted_condition = False
                
                # Check for if/while conditions
                if isinstance(ir, Condition):
                    for v in ir.read:
                        if v is not None and v in self.taint_graph:
                            tainted_condition = True
                            if self.verbose:
                                print(f"Found tainted condition variable: {v} in node {node.node_id}")

                # Check for require/assert calls
                elif isinstance(ir, SolidityCall) and (ir.function.name.startswith("require") or ir.function.name.startswith("assert")):
                    for v in ir.read:
                        if v is not None and v in self.taint_graph:
                            tainted_condition = True
                            if self.verbose:
                                print(f"Found tainted require/assert argument: {v} in node {node.node_id}")
                
                if tainted_condition:
                    # Mark the conditional node itself as tainted.
                    self.tainted_control_flow_nodes.add(node)
                    
                    # Find all nodes that are control-dependent on this tainted conditional
                    control_dependent_nodes = self._find_control_dependent_nodes(node)
                    if self.verbose:
                        print(f"Found {len(control_dependent_nodes)} control-dependent nodes for node {node.node_id}")
                        for dep_node in control_dependent_nodes:
                            print(f"  - Node {dep_node.node_id}")
                    
                    self.tainted_control_flow_nodes.update(control_dependent_nodes)
    
    def _find_control_dependent_nodes(self, conditional_node: Node) -> Set[Node]:
        """
        Finds all nodes that are control-dependent on the given conditional node.
        """
        control_dependent_nodes = set()
        
        if not hasattr(conditional_node, 'immediate_postdominator'):
            return control_dependent_nodes
            
        post_dominator = conditional_node.immediate_postdominator

        if not post_dominator or not conditional_node.sons:
            return control_dependent_nodes

        for successor in conditional_node.sons:
            nodes_to_visit = [successor]
            visited_in_path = {conditional_node}

            while nodes_to_visit:
                current_node = nodes_to_visit.pop(0)

                if current_node in visited_in_path or current_node == post_dominator:
                    continue
                visited_in_path.add(current_node)
                
                control_dependent_nodes.add(current_node)

                for son in current_node.sons:
                    if son not in visited_in_path:
                        nodes_to_visit.append(son)
        
        return control_dependent_nodes
    
    def _identify_taint_sinks(self, node: Node):
        """
        Identify taint sinks in a CFG node.
        """
        sinks = []

        for ir in node.irs:
            sink = None
            tainted_arg = None

            if hasattr(ir, 'arguments'):
                for arg in ir.arguments:
                    if arg and arg in self.taint_graph:
                        tainted_arg = arg
                        break

            # Sink 1: Direct Ether & ERC2O Token Transfer 
            if isinstance(ir, LowLevelCall) and ir.call_value and ir.call_value in self.taint_graph:
                sink = TaintSink(node=node, operation=ir, 
                                 sink_type="tainted_value_transfer", 
                                 tainted_variable=ir.call_value)
            elif isinstance(ir, (HighLevelCall, InternalCall)) and any(keyword in ir.function.name.lower() for keyword in self.TRANSFER_KEYWORDS):
                if tainted_arg:
                    sink = TaintSink(node=node, operation=ir, 
                                     sink_type="tainted_erc20_transfer", 
                                     tainted_variable=tainted_arg)

            # Sink 2: Internal Ledger Update - Identify internal functions that manipulate the contract's core economic ledger
            elif isinstance(ir, InternalCall) and tainted_arg:
                if ir.function and (ir.function.visibility == "internal" or ir.function.visibility == "private"):
                    # Check if this function modifies a mapping(address => uint256)
                    if self._is_ledger_update_function(ir.function):
                        sink = TaintSink(node=node, operation=ir, 
                                         sink_type="tainted_internal_ledger_update", 
                                         tainted_variable=tainted_arg)
            
            # Sink 3: Economic State Write - Identify SSTORE operations that write tainted values to user-claimable balances
            elif isinstance(ir, Assignment) and isinstance(ir.lvalue, (StateVariable, StateIRVariable, IndexAccess)):
                for read_var in ir.read:
                    if read_var and read_var in self.taint_graph:
                        # Check if the storage slot depends on msg.sender or other user input
                        if self._is_user_claimable_balance(ir.lvalue, node):
                            sink = TaintSink(node=node, operation=ir, 
                                             sink_type="tainted_economic_state_write", 
                                             tainted_variable=read_var)
                            break

            # Sink 4: State-changing external calls with a tainted argument
            elif tainted_arg and isinstance(ir, (HighLevelCall, LowLevelCall)):
                is_state_changing_call = True 
                if isinstance(ir, HighLevelCall):
                    # Heuristic: if the called function is view or pure, it's likely not a sink.
                    is_view = hasattr(ir.function, 'is_view') and ir.function.is_view
                    is_pure = hasattr(ir.function, 'is_pure') and ir.function.is_pure
                    if is_view or is_pure:
                        is_state_changing_call = False                  

                if is_state_changing_call:
                    sink = TaintSink(node=node, operation=ir, 
                                     sink_type="tainted_state_changing_external_call", 
                                     tainted_variable=tainted_arg)

            # If no tainted args but the node is in tainted_control_flow_nodes, we also mark it as tainted.        
            if not sink and node in self.tainted_control_flow_nodes:
                if (isinstance(ir, LowLevelCall) and ir.call_value) or (
                    isinstance(ir, (HighLevelCall, InternalCall)) and 
                    any(keyword in ir.function.name.lower() for keyword in self.TRANSFER_KEYWORDS)
                ):
                    sink = TaintSink(node=node, operation=ir, 
                                     sink_type="tainted_control_flow_transfer", 
                                     tainted_variable=None)
                elif isinstance(ir, InternalCall) and ir.function and (
                    ir.function.visibility == "internal" or ir.function.visibility == "private"
                ) and self._is_ledger_update_function(ir.function):
                    sink = TaintSink(node=node, operation=ir, 
                                     sink_type="tainted_control_flow_ledger_update", 
                                     tainted_variable=None)
                elif isinstance(ir, Assignment) and isinstance(ir.lvalue, (StateVariable, StateIRVariable, IndexAccess)) and self._is_user_claimable_balance(ir.lvalue, node):
                    sink = TaintSink(node=node, operation=ir, 
                                     sink_type="tainted_control_flow_state_write", 
                                     tainted_variable=None)
                elif isinstance(ir, (HighLevelCall, LowLevelCall)):
                    is_state_changing_call = True
                    if isinstance(ir, HighLevelCall):
                        is_view = hasattr(ir.function, 'is_view') and ir.function.is_view
                        is_pure = hasattr(ir.function, 'is_pure') and ir.function.is_pure
                        if is_view or is_pure:
                            is_state_changing_call = False
                    
                    if is_state_changing_call:
                        sink = TaintSink(node=node, operation=ir, 
                                         sink_type="tainted_control_flow_external_call", 
                                         tainted_variable=None)
            
            if sink and sink not in self.taint_sinks:
                self.taint_sinks.append(sink)
    
    def _find_taint_paths(self):
        """
        Finds paths from sources to sinks by backward analyzing the completed taint_graph.
        Also counts the total number of potential paths.
        """
        seen_paths = set()
        unique_sinks = set(self.taint_sinks)
        total_potential_paths = 0 
        
        for sink in unique_sinks:
            start_vars = []
            if sink.tainted_variable:
                start_vars.append(sink.tainted_variable)
            else:
                controlling_nodes = self._find_controlling_nodes(sink.node)
                for node in controlling_nodes:
                    for ir in node.irs:
                        if isinstance(ir, (Condition, SolidityCall)):
                            for v in ir.read:
                                if v and v in self.taint_graph:
                                    start_vars.append(v)
            
            for start_var in start_vars:
                path = []
                visited = set()
                curr_var = start_var
                
                while curr_var and curr_var not in visited:
                    visited.add(curr_var)
                    if curr_var not in self.taint_graph:
                        break
                    
                    op, parent_var = self.taint_graph[curr_var]
                    path.append(op)
                    
                    if parent_var is None:
                        for source in self.taint_sources:
                            if op == source.operation:
                                final_path = list(reversed(path))
                                total_potential_paths += 1
                                
                                # Check if we've seen this path before
                                path_key = (source, sink, tuple(str(op) for op in final_path))
                                if path_key not in seen_paths:
                                    seen_paths.add(path_key)
                                    self.taint_paths.append((source, sink, final_path))
                                break
                        break
                    else:
                        curr_var = parent_var

        self.total_potential_paths = total_potential_paths
    
    def _find_controlling_nodes(self, node: Node) -> Set[Node]:
        """
        Find nodes that control the execution of the given node through control flow.
        """
        controlling_nodes = set()
        function = node.function
        if not hasattr(function, 'nodes') or not function.nodes:
            return controlling_nodes

        conditional_nodes = [n for n in function.nodes if n.contains_if() or n.contains_require_or_assert()]
        
        for cond_node in conditional_nodes:
            dependent_nodes = self._find_control_dependent_nodes(cond_node)
            if node in dependent_nodes:
                controlling_nodes.add(cond_node)
        
        return controlling_nodes
    
    def _find_controlling_conditional_node(self, node: Node) -> Optional[Node]:
        """
        Finds the conditional node that a given node is control-dependent on.
        """
        controlling_nodes = self._find_controlling_nodes(node)
        for n in controlling_nodes:
            if n.contains_if() or n.contains_require_or_assert():
                return n
        return None
        
    def _is_ledger_update_function(self, function: Function) -> bool:
        """
        Determine if a function is a ledger update function by checking if it modifies a mapping(address => uint256) state variable 
        """
        if not function or not function.is_implemented:
            return False

        candidate_mappings = self._find_balance_mappings(function.contract)
        if not candidate_mappings:
            return False

        has_debit = False
        has_credit = False
        has_mint_like_op = False
        has_burn_like_op = False

        modified_mappings = {}

        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, Assignment) and isinstance(ir.lvalue, IndexAccess):
                    base_var = ir.lvalue.expression_left
                    if base_var in candidate_mappings:
                        if base_var not in modified_mappings:
                            modified_mappings[base_var] = {'credits': [], 'debits': []}
                        
                        if isinstance(ir.rvalue, Binary) and ir.rvalue.type == BinaryType.ADD:
                            has_credit = True
                            has_mint_like_op = True  # A credit can be part of a mint or transfer
                            if hasattr(ir.lvalue, 'index_expression'):
                                modified_mappings[base_var]['credits'].append(ir.lvalue.index_expression)
                        
                        elif isinstance(ir.rvalue, Binary) and ir.rvalue.type == BinaryType.SUB:
                            has_debit = True
                            has_burn_like_op = True  # A debit can be part of a burn or transfer
                            if hasattr(ir.lvalue, 'index_expression'):
                                modified_mappings[base_var]['debits'].append(ir.lvalue.index_expression)
        
        # The strongest signal: a function that does both a debit and a credit to the same mapping, which is a typical transfer
        for mapping_var, operations in modified_mappings.items():
            if operations['credits'] and operations['debits']:
                return True
            
        # Check function name for strong indicators
        if function.name:
            transfer_indicators = ['transfer', '_transfer', 'move', 'send', 'transferfrom']
            mint_indicators = ['mint', '_mint', 'create', 'issue']
            burn_indicators = ['burn', '_burn', 'destroy', 'redeem']
            
            func_name_lower = function.name.lower()
            
            if any(indicator in func_name_lower for indicator in transfer_indicators) and has_debit and has_credit:
                return True
                
            if any(indicator in func_name_lower for indicator in mint_indicators) and has_mint_like_op:
                return True
                
            if any(indicator in func_name_lower for indicator in burn_indicators) and has_burn_like_op:
                return True

        return False
    
    def _find_balance_mappings(self, contract: Contract) -> Set[StateVariable]:
        """
        Identify state variables most likely to represent user balance mappings.
        """
        candidates = set()
        
        if not contract or not hasattr(contract, 'state_variables'):
            return candidates
            
        for var in contract.state_variables:
            is_mapping = hasattr(var.type, 'is_mapping') and var.type.is_mapping

            if is_mapping and str(var.type).startswith("mapping(address => uint"):
                is_nested_mapping = "mapping(address =>" in str(var.type).split("uint")[0]
                
                # Prioritize variables with common names
                var_name_lower = var.name.lower() if hasattr(var, 'name') and var.name else ""
                
                highest_signal_keywords = ['balance', '_balance', 'credit', 'token', 'amount']
                medium_signal_keywords = ['staked', 'locked', 'reward', 'owed', 'share', 'deposit', 'asset']
                
                if any(keyword in var_name_lower for keyword in highest_signal_keywords):
                    candidates.add(var)
                elif any(keyword in var_name_lower for keyword in medium_signal_keywords):
                    candidates.add(var)
                elif not is_nested_mapping: 
                    candidates.add(var)
                    
        return candidates
        
    def _is_user_claimable_balance(self, lvalue, node: Node) -> bool:
        """
        Determines whether a storage write is to a user-claimable balance. 
        This occurs when both the value being written and the storage slot's key are tainted (e.g., depends on msg.sender or a tainted function parameter).
        """
        if not isinstance(lvalue, IndexAccess):
            return False
            
        index_variable = lvalue.index_expression

        # Check if the variable used as the key/index tainted
        if index_variable in self.taint_graph:
            return True

        # Heuristic: Check for direct use of msg.sender if taint tracking fails.
        if isinstance(index_variable, SolidityVariable) and index_variable.name == "msg.sender":
             return True
             
        # Heuristic: Check if the base variable name suggests a balance or reward 
        base_var = lvalue.expression_left
        if hasattr(base_var, 'name'):
            balance_keywords = {'balance', 'balances', 'reward', 'rewards', 'deposit', 'deposits', 'stake', 'stakes'}
            if any(keyword in base_var.name.lower() for keyword in balance_keywords):
                return True
             
        return False
