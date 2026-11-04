
import json
import os
import re 
import time
from pathlib import Path
from typing import Dict, List, Optional, Union, Any
from dotenv import load_dotenv
import openai
from pmdetector.llm.config import PAPER_TEMPERATURE

load_dotenv()

from pmdetector.llm.path_grouping import parse_source_code_taint_path, group_paths, format_path_groups

class MultiAgentAnalyzer:
    def __init__(
        self,
        model: str = "",
        temperature: float = PAPER_TEMPERATURE,
    ):
        self.model = model
        self.temperature = temperature
        self.client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def analyze(
        self,
        source_code: Union[str, Dict[str, str]],
        taint_paths: List[str],
        contract_name: Optional[str] = None
    ) -> Dict[str, Any]:
        source_code_str = self._prepare_source_code(source_code)
    
        if not taint_paths:
            print(f"Warning: No taint paths provided for contract {contract_name}")
            return {
                "is_vulnerable": False,
                "confidence": 1.0,
                "explanation": "No taint paths were found for analysis.",
                "vulnerable_functions": [],
                "vulnerable_paths": [],
                "vulnerable_groups": []
            }
            
        enhanced_paths = []
        temp_path = Path("experiments/temp_path.txt")
        with open(temp_path, "w") as f:
            f.write(f"# Taint Analysis Results with Source Code Mapping\n")
            f.write(f"Found {len(taint_paths)} tainted paths.\n\n")
            
            for i, path_str in enumerate(taint_paths, 1):
                if not path_str.strip().startswith("## Path #"):
                    f.write(f"## Path #{i}\n")
                f.write(path_str + "\n\n")
                f.write("----------------------------------------\n\n")
        
        parsed_paths = parse_source_code_taint_path(str(temp_path))
        enhanced_paths.extend(parsed_paths)
        temp_path.unlink()
        
        path_groups_dict = group_paths(enhanced_paths)
        
        path_groups = []
        for i, (group_key, paths) in enumerate(path_groups_dict.items()):
            source_func, sink_func, critical_ops = group_key
            group = {
                "group_id": i,
                "source_function": source_func,
                "sink_function": sink_func,
                "critical_operations": list(critical_ops),
                "paths": paths
            }
            path_groups.append(group)

        path_groups_str = format_path_groups(path_groups_dict, contract_name, baseline_name="multi_agent")
        self._store_formatted_path_groups(path_groups_str, contract_name)
        
        formatted_path_groups_file = Path(f"pmdetector/formatted_path_groups_multi_agent/{contract_name}_path_groups.txt")
        if formatted_path_groups_file.exists():
            with open(formatted_path_groups_file, "r") as f:
                path_groups_str = f.read()

            group_ids = []
            lines = path_groups_str.split("\n")
            current_group_id = None
            for line in lines:
                if line.startswith("Group #"):
                    try:
                        current_group_id = int(line.split("#")[1].strip(":"))
                        group_ids.append(current_group_id)
                    except (ValueError, IndexError):
                        pass
            
            for i, group in enumerate(path_groups):
                if i < len(group_ids):
                    group["group_id"] = group_ids[i]
                else:
                    group["group_id"] = i + 1
        
        # Step 1: Agent 1 (Triage Officer) - Filter paths
        verdicts = self._run_triage_agent(
            source_code_str,
            path_groups_str,
            contract_name
        )
        
        plausible_path_groups = []
        plausible_verdicts = []
        
        plausible_count = sum(1 for v in verdicts if v.get("verdict", "").upper() == "PLAUSIBLE")
        
        for verdict in verdicts:
            if verdict.get("verdict", "").upper() == 'PLAUSIBLE':
                reason = verdict.get("reason", "")
                group_index = verdict.get("group_id", "")
                for group in path_groups:
                    id = group.get("group_id")
                    if id == int(group_index):
                        group_copy = group.copy()
                        group_copy["plausible_reason"] = reason
                        plausible_path_groups.append(group_copy)
                        plausible_verdicts.append(verdict)
        
        print(f"Triage Officer identified {plausible_count} plausible path groups")
        print(f"Remaining plausible path groups: {len(plausible_path_groups)}")
        
        if plausible_path_groups:
            filtered_path_groups_str = format_path_groups(plausible_path_groups, contract_name, baseline_name="multi_agent")
        else:
            filtered_path_groups_str = "No plausible path groups identified by the Triage Officer."
        
        # Step 2: Agent 2 (Exploitation Analyst) - Generate vulnerability report
        final_report = self._run_exploitation_analyst(
            source_code_str,
            plausible_path_groups,
            filtered_path_groups_str,
            contract_name
        )
        
        return final_report
    
    def _prepare_source_code(self, source_code: Union[str, Dict[str, str]]) -> str:
        if isinstance(source_code, str):
            return source_code
        
        if isinstance(source_code, dict):
            result = []
            for file_path, content in source_code.items():
                result.append(f"// File: {file_path}")
                result.append(content)
                result.append("\n")
            return "\n".join(result)
        
        return ""
    
    def _run_triage_agent(
        self,
        source_code: str,
        path_groups_str: str,
        contract_name: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Run the Triage Officer agent to filter out benign paths.
        Returns: List of verdict dictionaries from the triage officer
        """
        print("Running Triage Officer agent...")

        prompt = self._create_triage_prompt(
            source_code,
            path_groups_str,
            contract_name,
        )

        response = self._call_llm_api(prompt)

        verdicts = self._parse_triage_response(response)

        plausible_count = 0
        for verdict in verdicts:
            if verdict.get('verdict') == 'PLAUSIBLE':
                pass
            group_id = verdict.get("group_id", "unknown")
            verdict_value = verdict.get("verdict", "").upper()
            
            if verdict_value == "PLAUSIBLE":
                plausible_count += 1
                print(f"  Path group {group_id} deemed PLAUSIBLE: {verdict.get('reason', '')}")
            else:
                print(f"  Path group {group_id} deemed BENIGN: {verdict.get('reason', '')}")
        
        print(f"Triage Officer identified {plausible_count} plausible path groups")
        
        return verdicts
    
    def _create_triage_prompt(
        self,
        source_code: str,
        path_groups_str: str,
        contract_name: Optional[str] = None,
    ) -> str:
        contract_info = f"Contract: {contract_name}\n\n" if contract_name else ""
        
        path_groups_info = []
        current_group = {}
        lines = path_groups_str.split('\n')
        
        for line in lines:
            line = line.strip()
            if line.startswith("Group #"):
                if current_group and "source_function" in current_group:
                    path_groups_info.append(current_group)
                current_group = {"group_id": line.split("#")[1].strip(":")}
            elif line.startswith("Source Function:"):
                current_group["source_function"] = line.replace("Source Function:", "").strip()
            elif line.startswith("Affected State:"):
                current_group["affected_states"] = line.replace("Affected State:", "").strip()
            elif line.startswith("Critical Operations:"):
                current_group["critical_operations"] = line.replace("Critical Operations:", "").strip()
            elif line.startswith("Key Steps:"):
                current_group["key_steps"] = []
                in_key_steps = True
            elif "key_steps" in current_group and line.startswith("    -"):
                current_group["key_steps"].append(line.strip())
        
        if current_group and "source_function" in current_group:
            path_groups_info.append(current_group)
        
        analysis_checklists = []
        for group in path_groups_info:
            group_id = group.get("group_id", "")
            source_function = group.get("source_function", "<unknown>")
            affected_states = group.get("affected_states", "<unknown>")
            critical_operations = group.get("critical_operations", "<unknown>")
            key_steps = "\n".join(group.get("key_steps", ["<unknown>"]))
            
            checklist = f"""**Analysis Checklist for Group #{group_id}:**
  1. Centralization Dependency Check: The entry point is {source_function}. Does this path's exploitability depend on a privileged role (owner, admin, vault, minter, operator, etc.) being malicious or compromised? 
  2. Economic Intent Check: The entry point {source_function} ultimately affecting {affected_states} via operations like {critical_operations}. Does this path describe a standard, intended economic mechanism of the protocol (e.g., ERC20 token contract), rather than an unintended flaw? 
  3. Mitigation Check: Review the code snippets in the Key Steps: {key_steps}. Are there any obvious mitigation (e.g., reentrancy modifiers, checks against a TWAP oracle, cooldown periods) in or around these lines that would prevent a flash-loan manipulation? 
  4. Exploit Type Check: The path modifies {affected_states}. Does this directly enable the theft of assets from a primary pool/treasury, or is the primary impact on governance power (e.g., voting delegates)?
"""
            analysis_checklists.append(checklist)
        
        all_checklists = "\n\n".join(analysis_checklists)
        
        prompt = f"""You are a smart contract auditor performing a rapid but rigorous triage on potential vulnerability paths. Your goal is to quickly identify and filter out paths that are clearly benign or represent theoretical, non-exploitable risks. 
 
 **Vulnerability Type:** Flash-loan-based price manipulation.

**Contract Information:**
{contract_info}

**Source Code:**
```solidity
{source_code}
```
{all_checklists}

**Final Decision:**
Based on your answers to the checklist for each path group, classify each path group as either PLAUSIBLE or BENIGN.
Provide your final verdict for each path group in the following JSON format. Return an array of verdicts, one for each path group.
[
  {{
    "group_id": "1",
    "verdict": "PLAUSIBLE" | "BENIGN",
    "reason": "Provide your one-sentence justification here. Example: 'BENIGN because the path entry point requires owner privileges (Centralization Dependency Check).' OR 'BENIGN because it describes the intended staking rewards mechanism (Economic Intent Check).' OR 'PLAUSIBLE because it describes an unmitigated spot price oracle used for a swap.'"
  }},
  ...
]
"""
        return prompt
    
    def _parse_triage_response(self, response: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Parse the response from the triage agent.
        """
        try:
            if not response or "choices" not in response or not response["choices"]:
                return [{
                    "group_id": "unknown",
                    "verdict": "BENIGN",
                    "reason": "Empty or invalid response from the triage agent."
                }]
                
            if "message" not in response["choices"][0] or "content" not in response["choices"][0]["message"]:
                return [{
                    "group_id": "unknown",
                    "verdict": "BENIGN",
                    "reason": "Invalid response structure from the triage agent."
                }]
                
            content = response["choices"][0]["message"]["content"]
            
            if content is None:
                return [{
                    "group_id": "unknown",
                    "verdict": "BENIGN",
                    "reason": "Null content in response from the triage agent."
                }]
            
            json_start = content.find("[")
            json_end = content.rfind("]") + 1
            
            if json_start == -1 or json_end == 0:
                json_start = content.find("{")
                json_end = content.rfind("}") + 1
                
                if json_start == -1 or json_end == 0:
                    raise ValueError("No JSON found in the response")
                
                json_str = content[json_start:json_end]
                single_result = json.loads(json_str)
                
                results = [single_result]
            else:
                json_str = content[json_start:json_end]
                results = json.loads(json_str)
            
            for result in results:
                if "verdict" not in result:
                    result["verdict"] = "BENIGN"  # Default to benign if no verdict
                
                if "reason" not in result:
                    result["reason"] = "No reason provided by the triage agent."
                
                if "group_id" not in result:
                    result["group_id"] = "unknown"
            
            return results
        except Exception as e:
            print(f"Error parsing triage response: {e}")
            print(f"Raw response: {response}")

            return [{
                "group_id": "unknown",
                "verdict": "BENIGN",
                "reason": f"Error parsing triage response: {str(e)}"
            }]
    
    def _run_exploitation_analyst(
        self,
        source_code: str,
        filtered_path_groups: List[Dict[str, Any]],
        filtered_path_groups_str: str,
        contract_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Run the Exploitation Analyst agent to generate a vulnerability report.
        """
        print("Running Exploitation Analyst agent...")
        
        if not filtered_path_groups:
            print("  No plausible paths found, returning not vulnerable report")
            return {
                "is_vulnerable": False,
                "confidence": 1.0,
                "explanation": "No plausible vulnerability paths were identified during triage.",
                "vulnerable_functions": [],
                "vulnerable_paths": [],
                "vulnerable_groups": []
            }
        

        print(f"  Found {len(filtered_path_groups)} plausible path groups.")
        
        prompt = self._create_exploitation_prompt(
            source_code,
            filtered_path_groups_str,
            contract_name
        )
        
        response = self._call_llm_api(prompt)
        
        final_report = self._parse_exploitation_response(response)
        
        for group in filtered_path_groups:
            group_id = group.get("group_id", "unknown")
            reason = group.get("plausible_reason", "Identified as plausible during triage")
            final_report["vulnerable_groups"].append({
                "group_id": group_id,
                "is_exploitable": True,
                "explanation": reason
            })
            
            if "paths" in group and group["paths"]:
                for path in group["paths"]:
                    try:
                        path_dict = path.to_dict() if hasattr(path, 'to_dict') else path
                        
                        if "source" in path_dict and path_dict["source"] and "function" in path_dict["source"]:
                            func_name = path_dict["source"]["function"]
                            if func_name and func_name not in final_report["vulnerable_functions"]:
                                final_report["vulnerable_functions"].append(func_name)
                    except Exception as e:
                        print(f"Error processing path: {e}")
                        continue
        
        return final_report
    
    def _create_exploitation_prompt(
        self,
        source_code: str,
        filtered_path_groups_str: str,
        contract_name: Optional[str] = None
    ) -> str:
        contract_info = f"Contract: {contract_name}\n\n" if contract_name else ""
        
        path_groups_info = []
        current_group = {}
        lines = filtered_path_groups_str.split('\n')
        
        for line in lines:
            line = line.strip()
            if line.startswith("Group #"):
                if current_group and "source_function" in current_group:
                    path_groups_info.append(current_group)
                current_group = {"group_id": line.split("#")[1].strip(":")}
            elif line.startswith("Source Function:"):
                current_group["source_function"] = line.replace("Source Function:", "").strip()
            elif line.startswith("Sink Function:"):
                current_group["sink_function"] = line.replace("Sink Function:", "").strip()
            elif line.startswith("Affected State:"):
                current_group["affected_states"] = line.replace("Affected State:", "").strip()
            elif line.startswith("Critical Operations:"):
                current_group["critical_operations"] = line.replace("Critical Operations:", "").strip()
            elif line.startswith("Key Steps:"):
                current_group["key_steps"] = []
                in_key_steps = True
            elif "key_steps" in current_group and line.startswith("    -"):
                current_group["key_steps"].append(line.strip())
        
        if current_group and "source_function" in current_group:
            path_groups_info.append(current_group)
        
        analysis_steps = []
        for group in path_groups_info:
            group_id = group.get("group_id", "")
            source_function = group.get("source_function", "<unknown>")
            sink_function = group.get("sink_function", "<unknown>")
            affected_states = group.get("affected_states", "<unknown>")
            critical_operations = group.get("critical_operations", "<unknown>")
            key_steps = "\n".join(group.get("key_steps", ["<unknown>"]))
            
            analysis = f"""Chain-of-Thought Analysis for Group #{group_id}:\\
    Step 1 (Oracle Identification): Based on the {affected_states} and {critical_operations} across the plausible paths, confirm the specific on-chain price source being manipulated.\\
    Step 2 (Manipulation Formulation): The {source_function} is the attacker's entry point. Starting from the entry point, construct the step-by-step attack scenario using the plausible paths. Explain how an attacker would profit.\\
    Step 3 (Profit Extraction Construction): The {sink_function} is where the attacker cashes out. After manipulating the price, how does the attacker leverage this function to their advantage?\\
    Step 4 (Defense Verification): Scrutinize the code for the functions involved {source_function}, {sink_function}, and the following key steps:
{key_steps}
    Double-check for any subtle defenses that might have been missed during triage that would invalidate the combined exploit path. Generate a verdict.\\
"""
            analysis_steps.append(analysis)
        
        all_analysis_steps = "\n\n".join(analysis_steps)
        
        prompt = f"""You are a smart contract security auditor specializing in DeFi economic exploits. We have already pre-filtered a list of plausible vulnerability paths. Your task is to analyze these high-potential paths to identify the definitive exploit scenario.

**ANALYSIS TASK**
**Contract Information:**
{contract_info}

**Source Code:**
```solidity
{source_code}
```

Now, perform your analysis and provide the final JSON output.
{all_analysis_steps}

**Final JSON Output:**
{{
"is_vulnerable": true/false,
"confidence": 0.0-1.0,
"explanation": "Detailed summary of your reasoning from the Chain-of-Thought analysis for each path group.",
"vulnerable_functions": Functions that are identified as vulnerable,
"vulnerable_groups": [
{{
"group_id": #1,
"is_exploitable": true/false,
"explanation": "Explanation of why this group represents an exploitable pattern or a benign one, based on the Chain-of-Thought analysis."
}}
]
}}

If there are no vulnerable groups, return an empty list for "vulnerable_groups".
"""
        
        return prompt
    
    def _parse_exploitation_response(self, response: Dict[str, Any]) -> Dict[str, Any]:
        """
        Parse the response from the exploitation analyst.
        """
        try:
            if "choices" in response and len(response["choices"]) > 0:
                if "message" in response["choices"][0] and "content" in response["choices"][0]["message"]:
                    content = response["choices"][0]["message"]["content"]
                else:
                    print("ERROR: Unexpected API response structure")
                    return {
                        "is_vulnerable": False,
                        "confidence": 0.0,
                        "explanation": "Unexpected API response structure",
                        "vulnerable_functions": [],
                        "vulnerable_paths": [],
                        "vulnerable_groups": []
                    }
            else:
                print("ERROR: No choices found in API response")
                return {
                    "is_vulnerable": False,
                    "confidence": 0.0,
                    "explanation": "No choices found in API response",
                    "vulnerable_functions": [],
                    "vulnerable_paths": [],
                    "vulnerable_groups": []
                }
            
            json_match = None
            json_block_patterns = [
                r'```json\s*(.*?)\s*```',  # Markdown JSON code block
                r'```\s*(\{.*?\})\s*```',   # Generic code block with JSON object
                r'```\s*(\[.*?\])\s*```'    # Generic code block with JSON array
            ]
            
            for pattern in json_block_patterns:
                matches = re.findall(pattern, content, re.DOTALL)
                if matches:
                    json_match = matches[0]
                    break
            
            if not json_match:
                json_start = content.find("{")
                json_end = content.rfind("}") + 1
                
                if json_start != -1 and json_end > json_start:
                    json_match = content[json_start:json_end]
            
            if not json_match:
                raise ValueError("No JSON found in the response")
            
            result = json.loads(json_match)

            required_fields = ["is_vulnerable", "confidence", "explanation"]
            for field in required_fields:
                if field not in result:
                    result[field] = None
            
            if "vulnerable_functions" not in result:
                result["vulnerable_functions"] = []
            
            if "vulnerable_paths" not in result:
                result["vulnerable_paths"] = []
            
            if "vulnerable_groups" not in result:
                result["vulnerable_groups"] = []
            
            return result
        except Exception as e:
            print(f"Error parsing exploitation response: {e}")
            # print(f"Raw response: {str(response)[:500]}...") 
            
            return {
                "is_vulnerable": False,
                "confidence": 0.0,
                "explanation": f"Error parsing exploitation response: {str(e)}",
                "vulnerable_functions": [],
                "vulnerable_paths": [],
                "vulnerable_groups": []
            }
    
    def _call_llm_api(self, prompt: str) -> Dict[str, Any]:
        max_retries = 3
        retry_delay = 5  # seconds
        
        for attempt in range(max_retries):
            try:
                print(f"Calling OpenAI API with model {self.model}, temperature={self.temperature} (attempt {attempt+1}/{max_retries})")
                
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    temperature=self.temperature
                )
                
                response_dict = {
                    "choices": [
                        {
                            "message": {
                                "content": response.choices[0].message.content
                            }
                        }
                    ]
                }
                
                return response_dict
                
            except Exception as e:
                print(f"Error during API call: {str(e)}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    print("Max retries reached, giving up.")

        print("All API call attempts failed")
        return {
            "choices": [
                {
                    "message": {
                        "content": '{"is_vulnerable": false, "confidence": 0.0, "explanation": "API call failed after multiple retries", "vulnerable_paths": [], "vulnerable_groups": []}'
                    }
                }
            ]
        }
    
    def _store_formatted_path_groups(self, path_groups_str: str, contract_id: Optional[str] = None) -> None:
        """
        Store formatted path groups in a dedicated folder.
        """
        path_groups_dir = Path("pmdetector/formatted_path_groups_multi_agent")
        path_groups_dir.mkdir(exist_ok=True, parents=True)
        
        if contract_id:
            filename = f"{contract_id}_path_groups.txt"

            output_path = path_groups_dir / filename
            if not output_path.exists():
                with open(output_path, "w") as f:
                    if isinstance(path_groups_str, str):
                        path_groups_str = path_groups_str.split('\n')
                    f.write("\n".join(path_groups_str))

                print(f"Stored formatted path groups to {output_path}")
            else:
                print(f"File {output_path} already exists, skipping write")
    
    def _analyze_single_contract(self, result_file, flattened_dir):
        """
        Analyze a single contract using the multi-agent approach.
        """
        try:
            contract_id = result_file.stem
            print(f"Analyzing contract: {contract_id}")
            
            contract_dir = flattened_dir / contract_id
            source_file = contract_dir / "flattened.sol"
            
            if not source_file.exists():
                print(f"Source file not found for {contract_id}")
                return contract_id, {
                    "is_vulnerable": False,
                    "confidence": 0.0,
                    "explanation": f"Source file not found for {contract_id}",
                    "vulnerable_functions": [],
                    "vulnerable_paths": [],
                    "vulnerable_groups": []
                }
            
            with open(source_file, "r", encoding="utf-8") as f:
                source_code = f.read()

            taint_path_file = Path(f"pmdetector/taint_paths_with_source/{contract_id}.txt")
            
            if not taint_path_file.exists():
                print(f"No taint path file found for {contract_id}")
                return contract_id, {
                    "is_vulnerable": False,
                    "confidence": 1.0,
                    "explanation": f"No taint paths were found for analysis for {contract_id}",
                    "vulnerable_functions": [],
                    "vulnerable_paths": [],
                    "vulnerable_groups": []
                }
            
            with open(taint_path_file, "r", encoding="utf-8") as f:
                taint_content = f.read()
            
            taint_paths = []
            lines = taint_content.split("\n")
            current_path = []
            in_path = False
            
            for line in lines:
                if line.startswith("## Path #"):
                    if current_path:
                        taint_paths.append("\n".join(current_path))
                        current_path = []
                    in_path = True
                    current_path.append(line)
                elif in_path:
                    current_path.append(line)
            
            if current_path:
                taint_paths.append("\n".join(current_path))
                
            if not taint_paths:
                print(f"No taint paths found in taint path file, trying result file for {contract_id}")
                try:
                    with open(result_file, "r", encoding="utf-8") as f:
                        result_content = f.read()
                    
                    lines = result_content.split("\n")
                    current_path = []
                    in_path = False
                    
                    for line in lines:
                        if line.startswith("=== Taint Path"):
                            if current_path:
                                taint_paths.append("\n".join(current_path))
                                current_path = []
                            in_path = True
                            current_path.append(line)
                        elif in_path:
                            current_path.append(line)
                    
                    if current_path:
                        taint_paths.append("\n".join(current_path))
                except Exception as e:
                    print(f"Error reading result file for {contract_id}: {str(e)}")
            
            result = self.analyze(source_code, taint_paths, contract_id)
            
            return contract_id, result
        except Exception as e:
            print(f"Error analyzing contract {result_file.stem}: {str(e)}")
            
            return result_file.stem, {
                "is_vulnerable": False,
                "confidence": 0.0,
                "explanation": f"Error during analysis: {str(e)}",
                "vulnerable_functions": [],
                "vulnerable_paths": [],
                "vulnerable_groups": []
            }
