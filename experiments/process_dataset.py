import os
import pandas as pd
import sys
import re
from pathlib import Path
import time
import hashlib
import traceback
from pmdetector.core.detector import TaintDetector
from pmdetector.utils.blockchain import get_contract_source
from pmdetector.llm.path_abstraction import taint_result_to_source_text
import solcx
from solcx import install_solc, set_solc_version
from solcx.install import get_solcx_install_folder, select_pragma_version
import shutil

def extract_solidity_version(file_path) -> str:
    """
    Extract the best Solidity compiler version from a .sol file.
    It uses solcx's 'select_pragma_version' on the first pragma found for robustness.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        pragma_specs = re.findall(r'pragma\s+solidity\s+([^;]+);', content)
        if not pragma_specs:
            print("No pragma solidity statement found, defaulting to 0.8.21")
            return "0.8.21"

        primary_pragma = pragma_specs[0].strip()
        
        # Check for exact version requirement (=X.Y.Z)
        exact_match = re.match(r'=\s*(\d+\.\d+\.\d+)', primary_pragma)
        if exact_match:
            exact_version = exact_match.group(1)
            print(f"Found exact version requirement: {exact_version}")
            return exact_version
            
        # First, try to find a compatible version among already installed ones.
        installed_versions = solcx.get_installed_solc_versions()
        compatible_version = select_pragma_version(primary_pragma, installed_versions)
        
        if compatible_version:
            return str(compatible_version)
        
        # If no installed version is compatible, we must pick one to install.
        # This is a heuristic since we can't know the "best" version from a range.
        # We'll pick the first concrete version number from the pragma string.
        print(f"No installed solc version matches pragma '{primary_pragma}'. Attempting to install a new one.")
        
        # Heuristic: find a version like '0.8.4' from '^0.8.4' or '>=0.8.4'
        match = re.search(r'(\d+\.\d+\.\d+)', primary_pragma)
        if match:
            return match.group(1)

        # Final fallback for pragmas without a full version number (e.g., '>0.8')
        print(f"Warning: Could not determine a specific version from pragma '{primary_pragma}', defaulting to 0.8.21")
        return "0.8.21"

    except Exception as e:
        print(f"Error extracting Solidity version: {e}")
        return "0.8.21"

def ensure_solc_version(version_string: str) -> str:
    """
    Ensure that the specified Solidity compiler version is installed and
    returns the path to its executable.
    """
    try:
        version = version_string
        
        # For older Solidity versions (0.5.x and below), try to find a compatible version first
        if version.startswith("0.5.") or version.startswith("0.4.") or version.startswith("0.3."):
            installed_versions = solcx.get_installed_solc_versions()
            major_minor = ".".join(version.split(".")[:2])  # Get "0.5" from "0.5.16"
            
            # Try to find an already installed compatible version
            compatible_versions = [v for v in installed_versions if str(v).startswith(major_minor)]
            if compatible_versions:
                # Use the highest compatible version
                compatible_version = max(compatible_versions)
                print(f"Using compatible installed version {compatible_version} for {version}")
                version = str(compatible_version)
        
        if version not in solcx.get_installed_solc_versions():
            print(f"Installing solc version {version}...")
            try:
                install_solc(version, show_progress=False)
            except Exception as e:
                print(f"Failed to install solc version {version}: {e}")
                # Try to find a similar version that's available
                try:
                    major_minor = ".".join(version.split(".")[:2])  # Get "0.5" from "0.5.16"
                    print(f"Trying to find alternative version for {major_minor}.x")
                    
                    # For 0.5.x, try 0.5.17 which is commonly available
                    if major_minor == "0.5":
                        alt_version = "0.5.17"
                    # For 0.4.x, try 0.4.26
                    elif major_minor == "0.4":
                        alt_version = "0.4.26"
                    else:
                        # For other versions, use 0.8.21 as fallback
                        alt_version = "0.8.21"
                        
                    print(f"Attempting to install alternative version {alt_version}")
                    install_solc(alt_version, show_progress=False)
                    version = alt_version
                except Exception as e2:
                    print(f"Failed to install alternative version: {e2}")
                    # Final fallback
                    version = "0.8.21"
                    if version not in solcx.get_installed_solc_versions():
                        install_solc(version, show_progress=False)
        
        set_solc_version(version, silent=True)
        install_folder = get_solcx_install_folder()
        solc_path = os.path.join(install_folder, f"solc-v{version}")

        print(f"Using solc version {version} (path: {solc_path})")
        return str(solc_path)
    except Exception as e:
        print(f"Error setting solc version {version_string}: {e}")
        latest = "0.8.21"
        if latest not in solcx.get_installed_solc_versions():
            install_solc(latest, show_progress=False)
        set_solc_version(latest, silent=True)
        
        install_folder = get_solcx_install_folder()
        solc_path = os.path.join(install_folder, f"solc-v{latest}")
        
        print(f"Using fallback solc version {latest} (path: {solc_path})")
        return str(solc_path)

def adapt_pragma_to_version(file_path, target_version):
    """
    Modify the pragma solidity statement in a file to match the target version.
    This is useful when we need to use a different compiler version than what's specified.
    
    Args:
        file_path: Path to the Solidity file
        target_version: The version to adapt the pragma to (e.g., "0.5.17")
    
    Returns:
        bool: True if the file was modified, False otherwise
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Find all pragma solidity statements
        pragma_matches = list(re.finditer(r'pragma\s+solidity\s+([^;]+);', content))
        if not pragma_matches:
            return False
        
        # Create a backup of the original file
        backup_path = str(file_path) + '.bak'
        shutil.copy2(file_path, backup_path)
        
        # Replace exact version requirements with the target version
        modified_content = content
        for match in reversed(pragma_matches):  # Process in reverse to maintain correct positions
            full_pragma = match.group(0)
            version_req = match.group(1)
            
            # Check if it's an exact version requirement
            if '=' in version_req:
                new_pragma = f"pragma solidity ^{target_version};"
                modified_content = modified_content[:match.start()] + new_pragma + modified_content[match.end():]
                print(f"Modified pragma from '{full_pragma}' to '{new_pragma}'")
        
        # Only write if changes were made
        if modified_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(modified_content)
            return True
        
        return False
    except Exception as e:
        print(f"Error adapting pragma: {e}")
        return False

def main(convert_to_source=False):
    flattened_dir = Path("pmdetector/flattened_contracts")
    results_dir = Path("pmdetector/analysis_results")
    source_code_paths_dir = Path("pmdetector/taint_paths_with_source")
    
    flattened_dir.mkdir(exist_ok=True)
    results_dir.mkdir(exist_ok=True)
    if convert_to_source:
        source_code_paths_dir.mkdir(exist_ok=True)

    dataset_path = Path("experiments/data/dataset/attack_dataset.xlsx")
    df = pd.read_excel(dataset_path)
    
    print(f"Processing {len(df)} contracts from the dataset...")
    
    detector = TaintDetector(verbose=False)
    
    for index, row in df.iterrows():
        protocol = row["Protocol"]
        address = row["Contract Address"]
        platform = row["Platform"].lower()
        label = row["Label"]
        
        print(f"\n[{index+1}/{len(df)}] Processing {protocol} ({address}) on {platform} - Label: {label}")
        
        blockchain_map = {"eth": "ethereum", "bsc": "bsc", "polygon": "polygon", "arb": "arb", "base": "base", "ftm": "fantom"}
        blockchain = blockchain_map.get(platform, "ethereum")
        
        contract_hash = hashlib.md5(f"{protocol}_{address}_{platform}".encode()).hexdigest()[:8]
        source_dir = flattened_dir / f"{contract_hash}_{protocol}"
        slithir_result_file = results_dir / f"{contract_hash}_{protocol}.txt"
        source_mapped_result_file = source_code_paths_dir / f"{contract_hash}_{protocol}.txt"

        # # If the goal is the source-mapped file, and it already exists, we are done.
        # if convert_to_source and source_mapped_result_file.exists():
        #     print(f"Source-mapped results already exist for {protocol}. Skipping.")
        #     continue
        
        # # If the goal is just the SlithIR file, and it exists, we are done.
        # if not convert_to_source and slithir_result_file.exists():
        #     print(f"SlithIR results already exist for {protocol}. Skipping.")
        #     continue
            
        print(f"Processing {protocol}...")

        if not source_dir.exists():
            print(f"Fetching source code for {protocol}...")
            source_data = get_contract_source(address, blockchain)
            
            if source_data:
                source_dir.mkdir(exist_ok=True)
                if isinstance(source_data, dict):
                    for filename, content in source_data.items():
                        sanitized_filename = filename.lstrip('/')
                        safe_filepath_part = Path(os.path.normpath(sanitized_filename))
                        if safe_filepath_part.is_absolute():
                            print(f"Skipping malicious path: {filename}")
                            continue
                        file_path = source_dir / safe_filepath_part
                        file_path.parent.mkdir(parents=True, exist_ok=True)
                        with open(file_path, "w", encoding="utf-8") as f:
                            f.write(content)
                    
                    # Create a flattened version of the multi-file contract
                    print(f"Multi-file project saved to {source_dir}")
                    print(f"Creating flattened.sol for multi-file project...")
                    
                    # Find all Solidity files
                    sol_files = list(source_dir.glob("**/*.sol"))
                    if sol_files:
                        # Combine all Solidity files into one
                        combined_content = "// SPDX-License-Identifier: MIT\n// Flattened contract combining multiple files\n\n"
                        
                        for sol_file in sol_files:
                            try:
                                with open(sol_file, 'r', encoding='utf-8', errors='ignore') as f:
                                    file_content = f.read()
                                    
                                # Add file separator and content
                                relative_path = sol_file.relative_to(source_dir)
                                combined_content += f"\n// File: {relative_path}\n"
                                combined_content += file_content
                                combined_content += "\n\n"
                            except Exception as e:
                                print(f"Error reading {sol_file}: {e}")
                        
                        # Save the combined content as flattened.sol
                        flattened_path = source_dir / "flattened.sol"
                        with open(flattened_path, "w", encoding="utf-8") as f:
                            f.write(combined_content)
                        print(f"Created flattened.sol with {len(sol_files)} combined files")
                    else:
                        print(f"No Solidity files found in {source_dir}, skipping flattening")
                elif isinstance(source_data, str):
                    if "vyper" in source_data.lower():
                        print(f"Detected Vyper contract for {protocol}, skipping.")
                        (source_dir / "contract.vy").write_text(source_data, encoding="utf-8")
                        continue
                    (source_dir / "flattened.sol").write_text(source_data, encoding="utf-8")
                    print(f"Single source file saved in {source_dir}")
            else:
                print(f"Failed to retrieve source code for {protocol} ({address})")
                continue
        else:
            print(f"Using existing source code from {source_dir}")
        
        try:
            sol_files = list(source_dir.glob("**/*.sol"))   # Ensure we are working with Solidity contracts
            if not sol_files:
                if list(source_dir.glob("**/*.vy")):
                     print(f"Detected Vyper contract for {protocol}, skipping.")
                     continue
                raise FileNotFoundError(f"No .sol files found in the source directory: {source_dir}")
            
            main_sol_file = source_dir / "flattened.sol"

            version_str = extract_solidity_version(str(main_sol_file))
            actual_version = version_str
            solc_path = ensure_solc_version(version_str)
            
            match = re.search(r'solc-v(\d+\.\d+\.\d+)', solc_path)
            if match:
                actual_version = match.group(1)

            if actual_version != version_str:
                print(f"Using version {actual_version} instead of {version_str}. Adapting pragma statements...")
                for sol_file in sol_files:
                    adapt_pragma_to_version(sol_file, actual_version)
            
            node_modules_dir = source_dir / 'node_modules'
            oz_dir = node_modules_dir / '@openzeppelin'
            solmate_dir = node_modules_dir / 'solmate'
            
            # Check if any file imports OpenZeppelin or solmate
            needs_oz = False
            needs_solmate = False
            for sol_file in sol_files:
                with open(sol_file, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if '@openzeppelin' in content or 'openzeppelin' in content:
                        needs_oz = True
                    if 'solmate' in content:
                        needs_solmate = True
                    if needs_oz and needs_solmate:
                        break
            
            # Create basic node_modules structure if needed
            if needs_oz and not oz_dir.exists():
                print(f"OpenZeppelin imports detected. Creating basic structure for {protocol}...")
                node_modules_dir.mkdir(exist_ok=True)
                oz_dir.mkdir(exist_ok=True, parents=True)
                
                # Create directory structure for common OpenZeppelin imports
                contracts_dir = oz_dir / 'contracts'
                contracts_dir.mkdir(exist_ok=True, parents=True)
                
                # Utils directory and files
                utils_dir = contracts_dir / 'utils'
                utils_dir.mkdir(exist_ok=True, parents=True)
                math_dir = utils_dir / 'math'
                math_dir.mkdir(exist_ok=True, parents=True)
                
                # Token directory and files
                token_dir = contracts_dir / 'token'
                token_dir.mkdir(exist_ok=True, parents=True)
                erc20_dir = token_dir / 'ERC20'
                erc20_dir.mkdir(exist_ok=True, parents=True)
                extensions_dir = erc20_dir / 'extensions'
                extensions_dir.mkdir(exist_ok=True, parents=True)
                utils_token_dir = erc20_dir / 'utils'
                utils_token_dir.mkdir(exist_ok=True, parents=True)
                
                # Access directory
                access_dir = contracts_dir / 'access'
                access_dir.mkdir(exist_ok=True, parents=True)
                
                # Security directory
                security_dir = contracts_dir / 'security'
                security_dir.mkdir(exist_ok=True, parents=True)
                
                # Interfaces directory
                interfaces_dir = contracts_dir / 'interfaces'
                interfaces_dir.mkdir(exist_ok=True, parents=True)
                
                # Create minimal Context.sol
                context_file = utils_dir / 'Context.sol'
                if not context_file.exists():
                    with open(context_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}""")
                
                # Create minimal SafeMath.sol
                safemath_file = math_dir / 'SafeMath.sol'
                if not safemath_file.exists():
                    with open(safemath_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}""")
                
                # Create minimal IERC20.sol
                ierc20_file = interfaces_dir / 'IERC20.sol'
                if not ierc20_file.exists():
                    with open(ierc20_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}""")
                
                # Create minimal ERC20.sol
                erc20_file = erc20_dir / 'ERC20.sol'
                if not erc20_file.exists():
                    with open(erc20_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IERC20.sol";
import "../../utils/Context.sol";

contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}""")
                
                # Create minimal Ownable.sol
                ownable_file = access_dir / 'Ownable.sol'
                if not ownable_file.exists():
                    with open(ownable_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/Context.sol";

abstract contract Ownable is Context {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor() {
        _transferOwnership(_msgSender());
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}""")
                
                # Create minimal SafeERC20.sol
                safeerc20_file = utils_token_dir / 'SafeERC20.sol'
                if not safeerc20_file.exists():
                    with open(safeerc20_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../interfaces/IERC20.sol";

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        token.transfer(to, value);
    }
    
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        token.transferFrom(from, to, value);
    }
    
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        token.approve(spender, value);
    }
}""")
                
                # Create minimal ReentrancyGuard.sol
                reentrancy_file = security_dir / 'ReentrancyGuard.sol'
                if not reentrancy_file.exists():
                    with open(reentrancy_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}""")
                
                # Create minimal Pausable.sol
                pausable_file = security_dir / 'Pausable.sol'
                if not pausable_file.exists():
                    with open(pausable_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/Context.sol";

abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    
    bool private _paused;
    
    constructor() {
        _paused = false;
    }
    
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}""")
                
                # Create minimal ERC20Burnable.sol
                erc20burnable_file = extensions_dir / 'ERC20Burnable.sol'
                if not erc20burnable_file.exists():
                    with open(erc20burnable_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../../../utils/Context.sol";

abstract contract ERC20Burnable is Context, ERC20 {
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
    
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _transfer(account, address(0), amount);
    }
}""")
                
                # Create minimal IERC20Metadata.sol
                ierc20metadata_file = extensions_dir / 'IERC20Metadata.sol'
                if not ierc20metadata_file.exists():
                    with open(ierc20metadata_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../interfaces/IERC20.sol";

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}""")
            
            # Create solmate structure if needed
            if needs_solmate and not solmate_dir.exists():
                print(f"Solmate imports detected. Creating basic structure for {protocol}...")
                solmate_dir.mkdir(exist_ok=True, parents=True)
                
                # Create tokens directory
                tokens_dir = solmate_dir / 'tokens'
                tokens_dir.mkdir(exist_ok=True, parents=True)
                
                # Create auth directory
                auth_dir = solmate_dir / 'auth'
                auth_dir.mkdir(exist_ok=True, parents=True)
                
                # Create minimal ERC20.sol for solmate
                solmate_erc20_file = tokens_dir / 'ERC20.sol'
                if not solmate_erc20_file.exists():
                    with open(solmate_erc20_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}""")
                
                # Create minimal Owned.sol for solmate
                owned_file = auth_dir / 'Owned.sol'
                if not owned_file.exists():
                    with open(owned_file, 'w', encoding='utf-8') as f:
                        f.write("""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Owned {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;
    }
}""")
            
            include_paths = [
                str(source_dir),
                str(source_dir / 'node_modules')
            ]

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

            live_results = detector.analyze_file(
                main_sol_file, 
                solc_path=solc_path, 
                solc_remaps=remaps, 
                solc_include_path=include_paths
            )
            
            with open(slithir_result_file, "w", encoding="utf-8") as f:
                f.write(live_results.to_text())
            print(f"SlithIR analysis results saved to {slithir_result_file}")
            
            if convert_to_source:
                print("Mapping taint paths to source code...")
                try:
                    source_code = {}
                    for source_file in source_dir.glob("**/*.sol"):
                        abs_path = str(source_file.resolve())
                        source_code[abs_path] = source_file.read_text(encoding="utf-8")
                        
                        filename = source_file.name
                        if filename not in source_code:  
                            source_code[filename] = source_file.read_text(encoding="utf-8")
                    
                    source_code_paths = taint_result_to_source_text(live_results, source_code)
                    
                    with open(source_mapped_result_file, "w", encoding="utf-8") as f:
                        f.write(source_code_paths)
                    
                    print(f"Source code mapping saved to {source_mapped_result_file}")
                except Exception as e:
                    print(f"ERROR: Could not map taint paths to source code for {protocol}: {e}")
                    traceback.print_exc() 
            
            time.sleep(1)
        except Exception as e:
            print(f"ERROR: Could not analyze {protocol}: {e}")
            traceback.print_exc()

if __name__ == "__main__":
    import sys
    convert_to_source = "--source" in sys.argv
    main(convert_to_source)
