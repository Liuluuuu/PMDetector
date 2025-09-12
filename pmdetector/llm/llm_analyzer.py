"""
Base LLM analyzer module for PMDetector.
"""

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

from pmdetector.core.taint_result import TaintResult


class LLMAnalyzer(ABC):
    """
    Base class for LLM analyzers.
    
    This class defines the interface for all LLM analyzers that will be used
    to analyze taint analysis results and determine if a contract is vulnerable.
    """
    
    def __init__(self, verbose: bool = False):
        """
        Initialize the LLM analyzer.
        
        Args:
            verbose: Whether to print verbose output.
        """
        self.verbose = verbose
    
    @abstractmethod
    def analyze(
        self,
        taint_result: TaintResult,
        source_code: Union[str, Dict[str, str]],
        attack_model: str,
        contract_name: Optional[str] = None
    ) -> Dict:
        """
        Analyze taint analysis results and determine if a contract is vulnerable.
        
        Args:
            taint_result: The taint analysis results.
            source_code: The source code of the contract, either as a string or a dictionary
                         mapping file names to their contents.
            attack_model: A description of the attack model in natural language.
            contract_name: The name of the contract, if available.
            
        Returns:
            A dictionary containing the analysis results, including:
            - is_vulnerable: Whether the contract is vulnerable.
            - confidence: The confidence level of the analysis (0-1).
            - explanation: An explanation of the analysis.
            - vulnerable_paths: A list of vulnerable paths, if any.
        """
        pass
    
    @abstractmethod
    def analyze_from_files(
        self,
        taint_result_path: Path,
        source_code_path: Path,
        attack_model: str
    ) -> Dict:
        """
        Analyze taint analysis results and determine if a contract is vulnerable,
        loading the data from files.
        
        Args:
            taint_result_path: Path to the taint analysis results file.
            source_code_path: Path to the source code directory or file.
            attack_model: A description of the attack model in natural language.
            
        Returns:
            A dictionary containing the analysis results, including:
            - is_vulnerable: Whether the contract is vulnerable.
            - confidence: The confidence level of the analysis (0-1).
            - explanation: An explanation of the analysis.
            - vulnerable_paths: A list of vulnerable paths, if any.
        """
        pass
