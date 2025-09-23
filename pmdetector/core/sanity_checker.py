from typing import Dict, List, Optional, Set
import re
import os
import sys
import shutil

from slither import Slither
from slither.core.declarations import Function, Contract
from slither.slithir.variables import Constant, StateIRVariable
from slither.slithir.operations import SolidityCall, LowLevelCall, HighLevelCall, InternalCall, Binary, BinaryType

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from experiments.process_dataset import extract_solidity_version, ensure_solc_version, adapt_pragma_to_version


class SanityChecker:
    # Common access control modifiers
    ACCESS_CONTROL_MODIFIERS = {
        'onlyOwner', 'onlyAdmin', 'onlyGovernance', 'onlyManager', 'onlyController',
        'onlyMinter', 'onlyOperator', 'onlyRole', 'onlyAuthorized', 'onlyVault',
        'auth', 'authorized', 'hasRole', 'ifAdmin', 'onlyThis'
    }

    # Common reentrancy guard modifiers
    REENTRANCY_GUARD_MODIFIERS = {
        'nonReentrant', 'noReentrant', 'reentrancyGuard', 'noReentrancy',
        'lockFunction', 'mutex', 'notEntered', 'notReentrant'
    }

    # DEX interaction functions
    DEX_INTERACTION_FUNCTIONS = {
        'swap', 'swapExactTokensForTokens', 'swapTokensForExactTokens',
        'swapExactETHForTokens', 'swapTokensForExactETH', 'swapExactTokensForETH',
        'swapETHForExactTokens', 'addLiquidity', 'removeLiquidity',
        'getAmountsOut', 'getAmountOut', 'getAmountsIn', 'getAmountIn',
        'swapAndLiquify', 'swapTokensForEth', 'swapETHForTokens'
    }

    # EIP-20 Standard Function Signatures and Common but non-standard extensions (e.g., from OpenZeppelin)
    STANDARD_TOKEN_OPERATIONS = {
        'totalSupply()',
        'balanceOf(address)',
        'transfer(address,uint256)',
        'transferFrom(address,address,uint256)',
        'approve(address,uint256)',
        'allowance(address,address)',
        'mint(address,uint256)',
        'burn(uint256)',
        'burnFrom(address,uint256)',
        'increaseAllowance(address,uint256)',
        'decreaseAllowance(address,uint256)',
    }

    # Price-sensitive systems
    PRICE_SENSITIVE_SYSTEMS = {
        'uniswap', 'sushiswap', 'pancakeswap', 'dex', 'amm', 'swap', 'oracle',
        'price', 'curve', 'balancer', 'lending', 'borrow', 'loan', 'collateral',
        'liquidate', 'liquidation', 'flash'
    }

    def __init__(self):
        self.slither = None
        self.contract_functions_map = {}  
        self.contract_modifiers_map = {}  
        self.contract_variables_map = {} 

    def check_vulnerabilities(self, source_code_path: str, llm_results: Dict) -> Dict:
        if not os.path.exists(source_code_path):
            print(f"Source code path does not exist: {source_code_path}")
            return llm_results
            
        try:
            version_str = extract_solidity_version(source_code_path)
            print(f"Extracted Solidity version: {version_str}")
            
            solc_path = ensure_solc_version(version_str)
            match = re.search(r'solc-v(\d+\.\d+\.\d+)', solc_path)
            actual_version = version_str
            if match:
                actual_version = match.group(1)
            
            if actual_version != version_str:
                print(f"Using version {actual_version} instead of {version_str}. Adapting pragma statements...")
                
                source_dir = os.path.dirname(source_code_path)
                temp_file = os.path.join(source_dir, "temp_" + os.path.basename(source_code_path))
                shutil.copy2(source_code_path, temp_file)
                
                adapt_pragma_to_version(temp_file, actual_version)

                source_code_path = temp_file
            
            source_dir = os.path.dirname(source_code_path)
            include_paths = [source_dir]
            
            node_modules_dir = os.path.join(source_dir, 'node_modules')
            if os.path.exists(node_modules_dir):
                include_paths.append(node_modules_dir)
            
            remaps = [
                f"@openzeppelin/={source_dir}/node_modules/@openzeppelin/",
                f"openzeppelin-contracts-upgradeable/={source_dir}/node_modules/openzeppelin-contracts-upgradeable/",
                f"openzeppelin-contracts/={source_dir}/node_modules/openzeppelin-contracts/",
                f"solmate/={source_dir}/node_modules/solmate/",
                f"hardhat/={source_dir}/node_modules/hardhat/",
                f"ds-test/={source_dir}/lib/ds-test/src/",
                f"forge-std/={source_dir}/lib/forge-std/src/",
                f"lib/={source_dir}/lib/"
            ]
            
            self.slither = Slither(
                source_code_path,
                solc=solc_path,
                solc_remaps=remaps,
                solc_args=f"--allow-paths {','.join(include_paths)}"
            )
            self._build_contract_maps()
            
            if actual_version != version_str and os.path.exists(temp_file):
                os.remove(temp_file)
                
        except Exception as e:
            print(f"Error initializing Slither: {e}")
            return llm_results

        refined_results = {}
        for contract_id, contract_data in llm_results.items():
            if not contract_data.get("is_vulnerable", False):
                refined_results[contract_id] = contract_data
                continue

            contract_name = None
            if "_" in contract_id:
                contract_name = contract_id.split("_", 1)[1]
            else:
                contract_name = contract_id
                
            contract = self._find_contract_by_name(contract_name)
            if not contract:
                print(f"Could not find contract for {contract_id}")
                refined_results[contract_id] = contract_data
                continue
                

            filtered_data = self._apply_filters(contract, contract_data)
            refined_results[contract_id] = filtered_data

        return refined_results

    def _build_contract_maps(self):
        for contract in self.slither.contracts:
            self.contract_functions_map[contract.name] = {func.name: func for func in contract.functions}
            self.contract_modifiers_map[contract.name] = {mod.name: mod for mod in contract.modifiers}
            self.contract_variables_map[contract.name] = {var.name: var for var in contract.state_variables}

    def _find_contract_by_name(self, contract_name: str) -> Optional[Contract]:
        if not contract_name:
            return None

        for contract in self.slither.contracts:
            if contract.name == contract_name:
                return contract

        for contract in self.slither.contracts:
            try:
                contract_name_str = str(contract.name)
                if contract_name_str.lower() == contract_name.lower():
                    return contract
            except Exception:
                continue

        for contract in self.slither.contracts:
            try:
                contract_name_str = str(contract.name)
                if contract_name.lower() in contract_name_str.lower():
                    return contract
            except Exception:
                continue
                
        for contract in self.slither.contracts:
            try:
                contract_name_str = str(contract.name)
                if contract_name_str.lower() in contract_name.lower():
                    return contract
            except Exception:
                continue
                
        if self.slither.contracts:
            main_contract = max(self.slither.contracts, 
                               key=lambda c: len(list(c.functions)) + len(list(c.state_variables)))
            print(f"Could not find exact contract match for {contract_name}, using main contract: {main_contract.name}")
            return main_contract

        return None

    def _apply_filters(self, contract: Contract, contract_data: Dict) -> Dict:
        vulnerable_functions = contract_data.get("vulnerable_functions", [])
        
        if self._is_known_tp_pattern(contract, vulnerable_functions):
            filter_status = "Verified True Positive"
            filter_reason = "Known Vulnerability Pattern Confirmed"
        else:
            filter_status = "Verified True Positive"  # Default
            filter_reason = None
            
            # FP Filtering
            if self._check_mitigations_present(contract, vulnerable_functions): 
                filter_status = "Filtered False Positive"
                filter_reason = "Mitigations Present"
            elif self._check_external_dependency(contract, vulnerable_functions): 
                filter_status = "Filtered False Positive"
                filter_reason = "External/Hypothetical Dependency"

        result = contract_data.copy()
        result["is_vulnerable"] = (filter_status == "Verified True Positive")
        result["filter_status"] = filter_status
        if filter_reason:
            result["filter_reason"] = filter_reason
        
        return result

    def _check_mitigations_present(self, contract: Contract, vulnerable_functions: List[str]) -> bool:
        found_dex_interaction = False
        for func_name in vulnerable_functions:
            function = self._find_function_in_contract(contract, func_name)
            if not function:
                continue
            
            # Traverse the call graph for DEX interactions
            if self._deep_interacts_with_dex(function, set()):
                found_dex_interaction = True
                if not self._path_is_mitigated(function, set()):
                    return False

        return found_dex_interaction

    def _check_external_dependency(self, contract: Contract, vulnerable_functions: List[str]) -> bool:
        if not vulnerable_functions:
            return False
        
        for func_name in vulnerable_functions:
            function = self._find_function_in_contract(contract, func_name)
            if not function:
                return False 

            if not self._is_standard_token_operation(function) or \
            (self._is_standard_token_operation(function) and not self._is_self_contained(function)):
                return False

        return True

    def _is_dex_interaction_ir(self, ir) -> bool:
        if hasattr(ir, 'function_name') and any(dex_func in ir.function_name.lower() for dex_func in self.DEX_INTERACTION_FUNCTIONS):
            return True
        if hasattr(ir, 'function') and ir.function and any(dex_func in ir.function.name.lower() for dex_func in self.DEX_INTERACTION_FUNCTIONS):
            return True
        return False
    
    def _find_function_in_contract(self, contract: Contract, func_name: str) -> Optional[Function]:
        if "." in func_name:
            parts = func_name.split(".")
            func_name = parts[-1]
        
        for function in contract.functions:
            if function.name == func_name:
                return function
        
        for function in contract.functions:
            try:
                function_name_str = str(function.name)
                if function_name_str.lower() == func_name.lower():
                    return function
            except Exception:
                continue
        
        for base_contract in contract.inheritance:
            for function in base_contract.functions:
                try:
                    if function.name == func_name:
                        return function
                    function_name_str = str(function.name)
                    if function_name_str.lower() == func_name.lower():
                        return function
                except Exception:
                    continue
        
        return None

    def _has_access_control(self, function: Function) -> bool:
        for modifier in function.modifiers:
            if modifier.name in self.ACCESS_CONTROL_MODIFIERS:
                return True

            try:
                modifier_name_str = str(modifier.name)
                if any(word in modifier_name_str.lower() for word in ['only', 'auth', 'admin', 'owner']):
                    return True
            except Exception:
                pass
        
        for node in function.nodes:
            if node.contains_require_or_assert():
                for ir in node.irs:
                    if isinstance(ir, SolidityCall) and ir.function.name.startswith("require"):
                        for read in ir.read:
                            if str(read) == "msg.sender":
                                return True
        
        return False

    def _interacts_with_dex(self, function: Function) -> bool:
        try:
            function_name_str = str(function.name)
            if any(dex_func in function_name_str.lower() for dex_func in self.DEX_INTERACTION_FUNCTIONS):
                return True
        except Exception:
            pass
        
        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, (HighLevelCall, LowLevelCall)):
                    if hasattr(ir, 'function_name'):
                        try:
                            func_name_str = str(ir.function_name)
                            if any(dex_func in func_name_str.lower() for dex_func in self.DEX_INTERACTION_FUNCTIONS):
                                return True
                        except Exception:
                            pass
                    if hasattr(ir, 'function') and ir.function:
                        try:
                            func_name_str = str(ir.function.name)
                            if any(dex_func in func_name_str.lower() for dex_func in self.DEX_INTERACTION_FUNCTIONS):
                                return True
                        except Exception:
                            pass
        
        return False

    def _has_reentrancy_guard(self, function: Function) -> bool:
        for modifier in function.modifiers:
            if modifier.name in self.REENTRANCY_GUARD_MODIFIERS:
                return True
            
            try:
                modifier_name_str = str(modifier.name)
                if any(word in modifier_name_str.lower() for word in ['reentrant', 'mutex', 'lock']):
                    return True
            except Exception:
                pass
        
        for node in function.nodes:
            for ir in node.irs:
                if hasattr(ir, 'lvalue') and hasattr(ir, 'rvalue'):
                    lvalue_str = str(ir.lvalue).lower()
                    if any(lock_word in lvalue_str for lock_word in ['lock', 'entered', 'mutex']):
                        return True
        
        return False

    def _has_cooldown_check(self, function: Function) -> bool:
        for node in function.nodes:
            if not node.contains_require_or_assert():
                continue
            
            for ir in node.irs:
                if not hasattr(ir, 'condition'):
                    continue

                condition = ir.condition
                if not isinstance(condition, Binary): # Only consider comparsion operations
                    continue
                
                if str(condition.variable_left) == "block.timestamp":
                    if isinstance(condition.variable_right, Binary) and condition.variable_right.type == BinaryType.ADDITION:
                        add_operands = [condition.variable_right.variable_left,
                                        condition.variable_right.variable_right]
                        # One operand should be a state var, andother should be the cooldown period (state var or const)
                        if any(isinstance(v, StateIRVariable) for v in add_operands):
                            return True
        
        return False

    def _check_fee_on_transfer_pattern(self, function: Function) -> bool:
        if function.name in ['_transfer', '_transferFrom']:
            for node in function.nodes:
                for ir in node.irs:
                    if isinstance(ir, InternalCall) and ir.function:
                        if self._deep_interacts_with_dex(ir.function, set()):
                            return True
        return False

    def _is_standard_token_operation(self, function: Function) -> bool:
        if function.signature_str in self.STANDARD_TOKEN_OPERATIONS:
            return True
        
        return False

    def _calls_price_sensitive_system(self, function: Function) -> bool:
        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, (HighLevelCall, LowLevelCall)):
                    if hasattr(ir, 'destination'):
                        dest_str = str(ir.destination).lower()
                        if any(system in dest_str for system in self.PRICE_SENSITIVE_SYSTEMS):
                            return True
                    
                    if hasattr(ir, 'function_name'):
                        try:
                            func_name_str = str(ir.function_name)
                            func_name = func_name_str.lower()
                            if any(system in func_name for system in self.PRICE_SENSITIVE_SYSTEMS):
                                return True
                        except Exception:
                            pass

                    if hasattr(ir, 'function') and ir.function:
                        try:
                            func_name_str = str(ir.function.name)
                            func_name = func_name_str.lower()
                            if any(system in func_name for system in self.PRICE_SENSITIVE_SYSTEMS):
                                return True
                        except Exception:
                            pass
        
        return False
    
    def _path_is_mitigated(self, function: Function, visited: Set[Function]) -> bool:
        if function in visited: return False
        visited.add(function)

        if self._has_reentrancy_guard(function):
            print(f"Mitigation Found in {function.name}: Re-entrancy guard.")
            return True

        if self._interacts_with_dex(function) and self._has_access_control(function):
            print(f"Mitigation Found in {function.name}: DEX interaction is access-controlled.")
            return True
        
        if self._has_cooldown_check(function):
            print(f"Mitigation Found in {function.name}: Cooldown/delay mechanism.")
            return True
            
        if self._check_fee_on_transfer_pattern(function):
            print(f"Mitigation Found in {function.name}: Swap is triggered from within a transfer (likely fee-on-transfer), not a direct exploit.")
            return True

        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, InternalCall) and ir.function:
                    if self._path_is_mitigated(ir.function, visited):
                        return True
        
        return False

    def _is_self_contained(self, function: Function) -> bool:
        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, (HighLevelCall, LowLevelCall)):
                    return False

        contract_and_ancestors = {c.name for c in function.contract.inheritance}
        contract_and_ancestors.add(function.contract.name)
        
        for var in function.state_variables_written:
            if var.contract.name not in contract_and_ancestors:
                return False

        return True

    def _is_known_tp_pattern(self, contract: Contract, vulnerable_functions: List[str]) -> bool:
        for func_name in vulnerable_functions:
            function = self._find_function_in_contract(contract, func_name)
            if not function: continue

            reads_own_balance = False
            calls_dex_with_spot_price = False
            for node in function.nodes:
                if "balanceOf(address(this))" in str(node.expression):
                    reads_own_balance = True

                for ir in node.irs:
                    if isinstance(ir, HighLevelCall) and ir.function_name in self.DEX_INTERACTION_FUNCTIONS:
                        calls_dex_with_spot_price = True
            
            if reads_own_balance and calls_dex_with_spot_price:
                print(f"TP Pattern Found in {function.name}: Reads own balance AND calls DEX.")
                return True

        return False

    def _deep_interacts_with_dex(self, function: Function, visited: Set[Function]) -> bool:
        if function in visited:
            return False
        visited.add(function)

        if self._interacts_with_dex(function):
            return True

        for node in function.nodes:
            for ir in node.irs:
                if isinstance(ir, InternalCall) and ir.function:
                    if self._deep_interacts_with_dex(ir.function, visited):
                        return True
        return False
