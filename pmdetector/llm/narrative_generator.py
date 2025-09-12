"""
Narrative generator module for PMDetector.
This module provides functions to generate narratives and evidence for taint path groups.
"""

import os
import json
import re
import http.client
import time
from typing import List, Dict, Tuple, Set, Any, Optional, Union
from pathlib import Path
from collections import defaultdict
from dotenv import load_dotenv

from pmdetector.llm.path_grouping import EnhancedTaintPath

load_dotenv()


class PathGroupNarrative:
    def __init__(self, 
                 group_id: int,
                 source_function: str, 
                 sink_function: str, 
                 paths: List[EnhancedTaintPath],
                 narrative: str = "",
                 key_evidence: List[Dict[str, str]] = None):
        self.group_id = group_id
        self.source_function = source_function
        self.sink_function = sink_function
        self.paths = paths
        self.narrative = narrative
        self.key_evidence = key_evidence or []
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            "group_id": self.group_id,
            "flow": f"{self.source_function} -> {self.sink_function}",
            "paths_represented": len(self.paths),
            "narrative": self.narrative,
            "key_evidence": self.key_evidence
        }
    
    def __str__(self) -> str:
        """String representation of the narrative."""
        result = []
        result.append(f"## Path Group #{self.group_id}: {self._generate_title()}")
        result.append(f"- Flow: {self.source_function} -> {self.sink_function}")
        result.append(f"- Paths Represented: {len(self.paths)}")
        result.append("")
        result.append(f"- Narrative: {self.narrative}")
        result.append("")
        result.append("- Key Steps with Code Evidence:")
        for evidence in self.key_evidence:
            result.append(f"  {evidence['step_number']}. `{evidence['code']}` @ `{evidence['file']}:{evidence['line']}`")
        
        return "\n".join(result)
    
    def _generate_title(self) -> str:
        """Generate a title for the path group based on source and sink functions."""
        source_parts = self.source_function.split(".")
        sink_parts = self.sink_function.split(".")
        
        source_contract = source_parts[0] if len(source_parts) > 1 else ""
        source_func = source_parts[-1]
        
        sink_contract = sink_parts[0] if len(sink_parts) > 1 else ""
        sink_func = sink_parts[-1]
        
        # If same contract, use function names
        if source_contract == sink_contract:
            return f"{source_func} to {sink_func} Flow"
        
        # Otherwise use contract and function names
        return f"{source_contract}.{source_func} to {sink_contract}.{sink_func} Flow"


def generate_narrative_prompt(source_func: str, sink_func: str, key_evidence: List[Dict[str, str]]) -> str:
    """
    Generate a prompt for the LLM to create a narrative.
    
    Args:
        source_func: Source function name
        sink_func: Sink function name
        key_evidence: List of evidence items
        
    Returns:
        Prompt string for the LLM
    """
    formatted_evidence = []
    for ev in key_evidence:
        formatted_evidence.append(f"- `{ev['code']}` @ `{ev['file']}:{ev['line']}`")
    
    prompt = f"""
Based on the following evidence from a smart contract data flow, write a single, concise sentence that describes the high-level action.

Source Function: {source_func}
Sink Function: {sink_func}
Key Steps:
{chr(10).join(formatted_evidence)}

Example 1:
Input: Source: initialize, Sink: liquidateBorrowFresh, Steps: _setComptroller, comptroller.liquidate...
Output: User-provided data during contract initialization directly configures the `comptroller`, which is later called to determine the amount of collateral to seize during a liquidation.

Example 2:
Input: Source: transferFrom, Sink: _transfer, Steps: _transfer, _balances[...].sub(...)
Output: An external call to transfer tokens results in a direct modification of the internal `_balances` mapping for both the sender and the recipient.

Now, generate the sentence for the provided evidence.
"""
    
    return prompt


class NarrativeGenerator:
    def __init__(
        self,
        api_host: str = "api.gpt.ge",
        api_endpoint: str = "/v1/chat/completions",
        model: str = "",
        temperature: float = 0,     # Ensure determinism of the result
        verbose: bool = False
    ):
        self.api_host = api_host
        self.api_endpoint = api_endpoint
        self.model = model
        self.temperature = temperature
        self.verbose = verbose
    
    def generate_narrative(
        self,
        source_func: str,
        sink_func: str,
        key_evidence: List[Dict[str, str]]
    ) -> str:
        """
        Generate a narrative for a path group using the LLM.
        """
        # Generate the prompt
        prompt = generate_narrative_prompt(source_func, sink_func, key_evidence)
        
        # Call the LLM API
        response = self._call_llm_api(prompt)
        
        # Parse the response
        return self._parse_response(response)
    
    def _call_llm_api(self, prompt: str) -> Dict[str, Any]:
        max_retries = 3
        retry_delay = 5  # seconds
        
        for attempt in range(max_retries):
            try:
                conn = http.client.HTTPSConnection(self.api_host)
                
                payload = json.dumps({
                    "model": self.model,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    "temperature": self.temperature,
                    "stream": False
                })
                
                headers = {
                    'Content-Type': 'application/json',
                    'Authorization': os.getenv('LLM_KEY')
                }
                
                if self.verbose:
                    print(f"Calling LLM API: {self.api_host}{self.api_endpoint} (attempt {attempt+1}/{max_retries})")
                
                # Set a timeout for the connection (10 seconds for connection, 60 seconds for response)
                conn.timeout = 60
                
                conn.request("POST", self.api_endpoint, payload, headers)
                res = conn.getresponse()
                data = res.read()
                
                if self.verbose:
                    print(f"API response status: {res.status}")
                
                # Check if the response is successful
                if res.status == 200:
                    response_data = json.loads(data.decode("utf-8"))
                    return response_data
                else:
                    print(f"API returned error status: {res.status}")
                    if attempt < max_retries - 1:
                        print(f"Retrying in {retry_delay} seconds...")
                        time.sleep(retry_delay)
                        # Increase retry delay for next attempt
                        retry_delay *= 2
                    else:
                        print("Max retries reached, giving up.")
                        break
            except json.JSONDecodeError as e:
                print(f"JSON decode error: {str(e)}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    print("Max retries reached, giving up.")
            except Exception as e:
                print(f"API call error: {str(e)}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    print("Max retries reached, giving up.")
        
        # If we get here, all retries failed
        print("All API call attempts failed")
        # Return a minimal response structure that won't cause parsing errors
        return {
            "choices": [
                {
                    "message": {
                        "content": "API call failed after multiple retries"
                    }
                }
            ]
        }
    
    def _parse_response(self, response: Dict[str, Any]) -> str:
        try:
            content = response["choices"][0]["message"]["content"]
            return content.strip()
        except Exception as e:
            if self.verbose:
                print(f"Error parsing LLM response: {e}")
                print(f"Raw response: {response}")
            
            return "Error generating narrative"

# Legacy function for backward compatibility
def generate_narrative_with_llm(prompt: str) -> str:
    """Legacy function that uses the new NarrativeGenerator class."""
    api_host = os.environ.get("LLM_API_HOST", "api.gpt.ge")
    api_endpoint = os.environ.get("LLM_API_ENDPOINT", "/v1/chat/completions")
    model = os.environ.get("LLM_MODEL", "qwen3-32b")
    verbose = os.environ.get("LLM_VERBOSE", "false").lower() == "true"
    
    generator = NarrativeGenerator(
        api_host=api_host,
        api_endpoint=api_endpoint,
        model=model,
        verbose=verbose
    )
    
    # Call the LLM API directly with the prompt
    response = generator._call_llm_api(prompt)
    
    # Parse the response
    return generator._parse_response(response)


def generate_narratives_for_groups(
    grouped_paths: Dict[Tuple, List[EnhancedTaintPath]],
    api_host: str = None,
    api_endpoint: str = None,
    model: str = None,
    verbose: bool = False
) -> List[PathGroupNarrative]:
    """
    Generate narratives for groups of taint paths.
    """
    narratives = []
    
    api_host = api_host or os.environ.get("LLM_API_HOST", "api.gpt.ge")
    api_endpoint = api_endpoint or os.environ.get("LLM_API_ENDPOINT", "/v1/chat/completions")
    model = model or os.environ.get("LLM_MODEL", "gpt-4.1-mini")
    verbose = verbose or os.environ.get("LLM_VERBOSE", "false").lower() == "true"
    
    generator = NarrativeGenerator(
        api_host=api_host,
        api_endpoint=api_endpoint,
        model=model,
        verbose=verbose
    )
    
    for i, (group_key, paths) in enumerate(grouped_paths.items(), 1):
        source_func, sink_func, _ = group_key
        
        # Extract key evidence
        key_evidence = extract_key_evidence(paths)
        
        # Generate narrative using the NarrativeGenerator
        narrative = generator.generate_narrative(source_func, sink_func, key_evidence)
        
        # Create PathGroupNarrative object
        group_narrative = PathGroupNarrative(
            group_id=i,
            source_function=source_func,
            sink_function=sink_func,
            paths=paths,
            narrative=narrative,
            key_evidence=key_evidence
        )
        
        narratives.append(group_narrative)
    
    return narratives


def generate_output_json(narratives: List[PathGroupNarrative]) -> Dict[str, Any]:
    """
    Generate the final output JSON.
    """
    return {
        "path_groups": [narrative.to_dict() for narrative in narratives]
    }
