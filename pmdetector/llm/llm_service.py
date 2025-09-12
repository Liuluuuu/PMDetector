"""
LLM service module for PMDetector.
This module provides functions to interact with LLM services for generating narratives.
"""

import os
import json
import logging
import requests
from typing import Dict, Any, Optional, List, Union

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class LLMService:
    """Base class for LLM services."""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize the LLM service.
        
        Args:
            api_key: API key for the LLM service
        """
        self.api_key = api_key or os.environ.get("LLM_API_KEY")
        if not self.api_key:
            logger.warning("No API key provided. Using placeholder responses.")
    
    def generate_text(self, prompt: str) -> str:
        """
        Generate text using the LLM service.
        
        Args:
            prompt: Prompt for the LLM
            
        Returns:
            Generated text
        """
        raise NotImplementedError("Subclasses must implement generate_text")


class OpenAIService(LLMService):
    """OpenAI LLM service."""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "gpt-4"):
        """
        Initialize the OpenAI service.
        
        Args:
            api_key: OpenAI API key
            model: OpenAI model to use
        """
        super().__init__(api_key or os.environ.get("OPENAI_API_KEY"))
        self.model = model
        
        # Import OpenAI library if available
        try:
            import openai
            self.client = openai.OpenAI(api_key=self.api_key)
            self.use_library = True
        except ImportError:
            logger.warning("OpenAI library not found. Using requests instead.")
            self.use_library = False
    
    def generate_text(self, prompt: str) -> str:
        """
        Generate text using the OpenAI API.
        
        Args:
            prompt: Prompt for the LLM
            
        Returns:
            Generated text
        """
        if not self.api_key:
            return self._generate_placeholder(prompt)
        
        try:
            if self.use_library:
                return self._generate_with_library(prompt)
            else:
                return self._generate_with_requests(prompt)
        except Exception as e:
            logger.error(f"Error generating text with OpenAI: {e}")
            return self._generate_placeholder(prompt)
    
    def _generate_with_library(self, prompt: str) -> str:
        """Generate text using the OpenAI library."""
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": "You are a helpful assistant that generates concise, accurate descriptions of smart contract vulnerabilities based on taint analysis results."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=200
        )
        
        return response.choices[0].message.content.strip()
    
    def _generate_with_requests(self, prompt: str) -> str:
        """Generate text using requests."""
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        
        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": "You are a helpful assistant that generates concise, accurate descriptions of smart contract vulnerabilities based on taint analysis results."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 200
        }
        
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=data
        )
        
        if response.status_code == 200:
            return response.json()["choices"][0]["message"]["content"].strip()
        else:
            logger.error(f"Error from OpenAI API: {response.text}")
            return self._generate_placeholder(prompt)
    
    def _generate_placeholder(self, prompt: str) -> str:
        """Generate a placeholder response."""
        import re
        
        # Extract source and sink from the prompt
        source_match = re.search(r"Source Function: (.*?)$", prompt, re.MULTILINE)
        sink_match = re.search(r"Sink Function: (.*?)$", prompt, re.MULTILINE)
        
        if source_match and sink_match:
            source = source_match.group(1)
            sink = sink_match.group(1)
            return f"User-controlled input from {source} flows to {sink}, potentially allowing manipulation of critical contract state or external interactions."
        
        return "A potential vulnerability exists where user-controlled input can affect critical contract operations."


class AnthropicService(LLMService):
    """Anthropic LLM service."""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "claude-3-opus-20240229"):
        """
        Initialize the Anthropic service.
        
        Args:
            api_key: Anthropic API key
            model: Anthropic model to use
        """
        super().__init__(api_key or os.environ.get("ANTHROPIC_API_KEY"))
        self.model = model
        
        # Import Anthropic library if available
        try:
            import anthropic
            self.client = anthropic.Anthropic(api_key=self.api_key)
            self.use_library = True
        except ImportError:
            logger.warning("Anthropic library not found. Using requests instead.")
            self.use_library = False
    
    def generate_text(self, prompt: str) -> str:
        """
        Generate text using the Anthropic API.
        
        Args:
            prompt: Prompt for the LLM
            
        Returns:
            Generated text
        """
        if not self.api_key:
            return self._generate_placeholder(prompt)
        
        try:
            if self.use_library:
                return self._generate_with_library(prompt)
            else:
                return self._generate_with_requests(prompt)
        except Exception as e:
            logger.error(f"Error generating text with Anthropic: {e}")
            return self._generate_placeholder(prompt)
    
    def _generate_with_library(self, prompt: str) -> str:
        """Generate text using the Anthropic library."""
        response = self.client.messages.create(
            model=self.model,
            system="You are a helpful assistant that generates concise, accurate descriptions of smart contract vulnerabilities based on taint analysis results.",
            messages=[
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=200
        )
        
        return response.content[0].text
    
    def _generate_with_requests(self, prompt: str) -> str:
        """Generate text using requests."""
        headers = {
            "Content-Type": "application/json",
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01"
        }
        
        data = {
            "model": self.model,
            "system": "You are a helpful assistant that generates concise, accurate descriptions of smart contract vulnerabilities based on taint analysis results.",
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 200
        }
        
        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers=headers,
            json=data
        )
        
        if response.status_code == 200:
            return response.json()["content"][0]["text"]
        else:
            logger.error(f"Error from Anthropic API: {response.text}")
            return self._generate_placeholder(prompt)
    
    def _generate_placeholder(self, prompt: str) -> str:
        """Generate a placeholder response."""
        import re
        
        # Extract source and sink from the prompt
        source_match = re.search(r"Source Function: (.*?)$", prompt, re.MULTILINE)
        sink_match = re.search(r"Sink Function: (.*?)$", prompt, re.MULTILINE)
        
        if source_match and sink_match:
            source = source_match.group(1)
            sink = sink_match.group(1)
            return f"User-controlled input from {source} flows to {sink}, potentially allowing manipulation of critical contract state or external interactions."
        
        return "A potential vulnerability exists where user-controlled input can affect critical contract operations."


def get_llm_service(service_name: str = "openai", api_key: Optional[str] = None, model: Optional[str] = None) -> LLMService:
    """
    Get an LLM service instance.
    
    Args:
        service_name: Name of the LLM service (openai or anthropic)
        api_key: API key for the LLM service
        model: Model to use
        
    Returns:
        LLM service instance
    """
    if service_name.lower() == "openai":
        return OpenAIService(api_key=api_key, model=model or "gpt-4")
    elif service_name.lower() == "anthropic":
        return AnthropicService(api_key=api_key, model=model or "claude-3-opus-20240229")
    else:
        logger.warning(f"Unknown LLM service: {service_name}. Using OpenAI.")
        return OpenAIService(api_key=api_key, model=model or "gpt-4")


def generate_narrative_with_llm(prompt: str, service_name: str = "openai", api_key: Optional[str] = None, model: Optional[str] = None) -> str:
    service = get_llm_service(service_name, api_key, model)
    return service.generate_text(prompt)
