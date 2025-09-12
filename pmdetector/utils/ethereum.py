"""
Ethereum utility functions for the PMDetector taint analysis tool.
"""

import json
import os
import requests
from typing import Optional


def get_contract_source(address: str) -> Optional[str]:
    """
    Retrieve the source code for a contract at the given Ethereum address.
    
    Args:
        address: Ethereum contract address
        
    Returns:
        Source code as a string, or None if not found
    """
    # Try to get source code from Etherscan
    source = _get_source_from_etherscan(address)
    if source:
        return source
    
    # Try to get source code from Sourcify
    source = _get_source_from_sourcify(address)
    if source:
        return source
    
    return None


def _get_source_from_etherscan(address: str) -> Optional[str]:
    """
    Retrieve source code from Etherscan API.
    
    Args:
        address: Ethereum contract address
        
    Returns:
        Source code as a string, or None if not found
    """
    # Get Etherscan API key from environment variable
    api_key = os.environ.get("ETHERSCAN_API_KEY")
    if not api_key:
        return None
    
    # Prepare API request
    url = "https://api.etherscan.io/api"
    params = {
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": api_key
    }
    
    try:
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["status"] == "1" and data["result"]:
            source_code = data["result"][0]["SourceCode"]
            if source_code and source_code != "":
                return source_code
    except Exception as e:
        print(f"Error retrieving source from Etherscan: {e}")
    
    return None


def _get_source_from_sourcify(address: str) -> Optional[str]:
    """
    Retrieve source code from Sourcify API.
    
    Args:
        address: Ethereum contract address
        
    Returns:
        Source code as a string, or None if not found
    """
    # Prepare API request
    url = f"https://sourcify.dev/server/files/any/{address}"
    
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            
            # Extract source code from response
            for file_path, content in data.items():
                if file_path.endswith(".sol"):
                    return content
    except Exception as e:
        print(f"Error retrieving source from Sourcify: {e}")
    
    return None
