import json
import os
import re
import requests
import time
import tempfile
from pathlib import Path
from typing import Optional, Dict, List, Union

BLOCKCHAIN_APIS = {
    "ethereum": {
        "explorer_api": "https://api.etherscan.io/api",
        "explorer_env_var": "ETHERSCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/any/{address}"
    },
    "arb": {
        "explorer_api": "https://api.arbiscan.io/api",
        "explorer_env_var": "ARBISCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/42161/{address}"
    },
    "base": {
        "explorer_api": "https://api.basescan.org/api",
        "explorer_env_var": "BASESCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/8453/{address}"
    },
    "bsc": {
        "explorer_api": "https://api.bscscan.com/api",
        "explorer_env_var": "BSCSCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/56/{address}"
    },
    "polygon": {
        "explorer_api": "https://api.polygonscan.com/api",
        "explorer_env_var": "POLYGONSCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/137/{address}"
    },
    "fantom": {
        "explorer_api": "https://api.ftmscan.com/api",
        "explorer_env_var": "FTMSCAN_API_KEY",
        "sourcify_api": "https://sourcify.dev/server/files/250/{address}"
    }
}

def get_contract_source(address: str, blockchain: str = "ethereum") -> Optional[Union[str, Dict[str, str]]]:
    """
    Retrieve the source code for a contract at the given blockchain address.
    Returns either a string (single file) or a dictionary of files (multi-file project).
    """
    if blockchain not in BLOCKCHAIN_APIS:
        raise ValueError(f"Unsupported blockchain: {blockchain}. Supported blockchains: {', '.join(BLOCKCHAIN_APIS.keys())}")
    
    source = _get_source_from_explorer(address, blockchain)
    if source:
        return source
    
    # If cannot retrieve source code from explorer, then try to get source code from Sourcify
    source = _get_source_from_sourcify(address, blockchain)
    if source:
        return source
    
    return None


def _get_source_from_explorer(address: str, blockchain: str) -> Optional[str]:
    """
    Retrieve source code from blockchain explorer API.
    """
    api_config = BLOCKCHAIN_APIS[blockchain]
    
    api_key = os.environ.get(api_config["explorer_env_var"])
    if not api_key:
        print(f"No API key found for {blockchain} in environment variable {api_config['explorer_env_var']}")
        return None

    url = api_config["explorer_api"]
    params = {
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": api_key
    }
    
    try:
        max_retries = 3
        retry_count = 0
        backoff_time = 1  # Start with 1 second backoff
        
        while retry_count < max_retries:
            try:
                print(f"Requesting source code from {blockchain} explorer for address {address}")
                response = requests.get(url, params=params, timeout=30)  # Add timeout
                
                response.raise_for_status()
                
                data = response.json()
                
                if data.get("status") == "1" and data.get("result"):
                    source_code = data["result"][0].get("SourceCode")
                    if source_code and source_code != "":
                        print(f"Successfully retrieved source code from {blockchain} explorer")
                        return process_source_code(source_code)
                    else:
                        print(f"Empty source code returned from {blockchain} explorer")
                else:
                    error_msg = data.get("message", "Unknown error")
                    print(f"API error from {blockchain} explorer: {error_msg}")
                
                break 
                
            except requests.exceptions.SSLError as ssl_err:
                retry_count += 1
                if retry_count >= max_retries:
                    print(f"SSL Error after {max_retries} attempts: {ssl_err}")
                    print("This may be due to LibreSSL compatibility issues. Consider using a Python installation with OpenSSL 1.1.1+")
                    break
                print(f"SSL Error, retrying ({retry_count}/{max_retries}): {ssl_err}")
                time.sleep(backoff_time)
                backoff_time *= 2  # Exponential backoff
                
            except requests.exceptions.RequestException as req_err:
                retry_count += 1
                if retry_count >= max_retries:
                    print(f"Network error after {max_retries} attempts: {req_err}")
                    break
                print(f"Network error, retrying ({retry_count}/{max_retries}): {req_err}")
                time.sleep(backoff_time)
                backoff_time *= 2  # Exponential backoff
                
    except Exception as e:
        print(f"Unexpected error retrieving source from {blockchain} explorer: {e}")
    
    return None


def process_source_code(source_code: any) -> Optional[Union[str, Dict[str, str]]]:
    if isinstance(source_code, dict):
        source_code = json.dumps(source_code)
    
    if not isinstance(source_code, str):
        return None

    if source_code.strip().startswith("# @version"):
        print("Detected Vyper contract, skipping as we only focus on Solidity")
        return None

    if source_code.strip().startswith("{{") or source_code.strip().startswith("{"):
        try:
            json_str = source_code.strip()
            if json_str.startswith("{{") and json_str.endswith("}}"):
                json_str = json_str[1:-1]
            
            json_data = json.loads(json_str)
            sources = json_data.get("sources", json_data)
            
            if isinstance(sources, dict) and any(file.endswith(".sol") for file in sources.keys()):
                cleaned_sources = {}
                for file_name, file_data in sources.items():
                    if file_name.endswith(".sol"):
                        content = file_data.get("content") if isinstance(file_data, dict) else file_data
                        cleaned_sources[file_name] = content
                
                if cleaned_sources:
                    print("Detected multi-file project.")
                    return cleaned_sources

        except json.JSONDecodeError:
            pass

    lines = source_code.splitlines()
    spdx_found = False
    processed_lines = []
    for line in lines:
        if "SPDX-License-Identifier" in line:
            if not spdx_found:
                processed_lines.append(line)
                spdx_found = True
        else:
            processed_lines.append(line)
    
    print("Detected single flattened contract.")
    return "\n".join(processed_lines)


def _get_source_from_sourcify(address: str, blockchain: str) -> Optional[Union[str, Dict[str, str]]]:
    api_config = BLOCKCHAIN_APIS[blockchain]
    
    url = api_config["sourcify_api"].format(address=address)
    
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            
            if isinstance(data, dict):
                sol_files = {path: content for path, content in data.items() if path.endswith(".sol")}
                if len(sol_files) > 1:
                    print("Detected multi-file project from Sourcify.")
                    return sol_files
                elif len(sol_files) == 1:
                    file_path = next(iter(sol_files.keys()))
                    print(f"Detected single file from Sourcify: {file_path}")
                    return sol_files[file_path]
            
            elif isinstance(data, list):
                sol_files = {}
                for file_obj in data:
                    if isinstance(file_obj, dict) and "name" in file_obj and "content" in file_obj:
                        file_path = file_obj["name"]
                        if file_path.endswith(".sol"):
                            sol_files[file_path] = file_obj["content"]
                
                if len(sol_files) > 1:
                    print("Detected multi-file project from Sourcify.")
                    return sol_files
                elif len(sol_files) == 1:
                    file_path = next(iter(sol_files.keys()))
                    print(f"Detected single file from Sourcify: {file_path}")
                    return sol_files[file_path]
            
            flattened_source = ""
            if isinstance(data, dict):
                for file_path in sorted(data.keys()):
                    if file_path.endswith(".sol"):
                        content = data[file_path]

                        flattened_source += f"\n// Source: {file_path}\n"
                        flattened_source += content + "\n"
            elif isinstance(data, list):
                for file_obj in data:
                    if isinstance(file_obj, dict) and "name" in file_obj and "content" in file_obj:
                        file_path = file_obj["name"]
                        if file_path.endswith(".sol"):
                            content = file_obj["content"]

                            flattened_source += f"\n// Source: {file_path}\n"
                            flattened_source += content + "\n"
            
            if flattened_source:
                print("Returning flattened source from Sourcify.")
                return flattened_source.strip()
    except Exception as e:
        print(f"Error retrieving source from Sourcify for {blockchain}: {e}")
    
    return None
