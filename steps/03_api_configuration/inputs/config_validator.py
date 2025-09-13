#!/usr/bin/env python3
"""
API Configuration Validator for OpenRCA Pipeline
Validates API configurations without making actual API calls
"""
import os
import re
import yaml
import json
import sys
from typing import Dict, List, Any, Optional
from pathlib import Path

class APIConfigValidator:
    def __init__(self):
        self.supported_providers = {
            "OpenAI": {
                "models": [
                    "gpt-4o-2024-05-13",
                    "gpt-4-turbo", 
                    "gpt-4",
                    "gpt-3.5-turbo"
                ],
                "api_key_pattern": r"^sk-[A-Za-z0-9]{48,}$",
                "required_fields": ["SOURCE", "MODEL", "API_KEY"]
            },
            "Anthropic": {
                "models": [
                    "claude-3-sonnet-20240229",
                    "claude-3-haiku-20240307", 
                    "claude-3-opus-20240229",
                    "claude-2.1",
                    "claude-2"
                ],
                "api_key_pattern": r"^sk-ant-[A-Za-z0-9-_]{95,}$",
                "required_fields": ["SOURCE", "MODEL", "API_KEY"]
            }
        }
        
        self.validation_results = {
            "validation_status": "pending",
            "provider": None,
            "model": None,
            "errors": [],
            "warnings": [],
            "capabilities": {},
            "security_check": "passed"
        }
    
    def validate_config(self, config_path: str) -> Dict[str, Any]:
        """Validate the complete API configuration"""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            
            # Basic structure validation
            self._validate_structure(config)
            
            # Provider-specific validation
            self._validate_provider(config)
            
            # Model validation
            self._validate_model(config)
            
            # API key validation (format only, no calls)
            self._validate_api_key(config)
            
            # Parameter validation
            self._validate_parameters(config)
            
            # Security validation
            self._validate_security(config)
            
            # Rate limiting validation
            self._validate_rate_limits(config)
            
            # Set capabilities
            self._detect_capabilities(config)
            
            # Determine final status
            if not self.validation_results["errors"]:
                self.validation_results["validation_status"] = "success"
            else:
                self.validation_results["validation_status"] = "failed"
                
        except Exception as e:
            self.validation_results["errors"].append(f"Configuration validation error: {str(e)}")
            self.validation_results["validation_status"] = "failed"
        
        return self.validation_results
    
    def _validate_structure(self, config: Dict[str, Any]):
        """Validate basic configuration structure"""
        required_top_level = ["SOURCE", "MODEL", "API_KEY"]
        
        for field in required_top_level:
            if field not in config:
                self.validation_results["errors"].append(f"Missing required field: {field}")
        
        # Check for environment variable substitution
        for key, value in config.items():
            if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
                env_var = value[2:-1]
                if env_var not in os.environ:
                    self.validation_results["warnings"].append(
                        f"Environment variable {env_var} not set for {key}"
                    )
    
    def _validate_provider(self, config: Dict[str, Any]):
        """Validate provider configuration"""
        provider = config.get("SOURCE")
        
        if not provider:
            self.validation_results["errors"].append("SOURCE (provider) not specified")
            return
        
        if provider not in self.supported_providers:
            self.validation_results["errors"].append(
                f"Unsupported provider: {provider}. Supported: {list(self.supported_providers.keys())}"
            )
            return
        
        self.validation_results["provider"] = provider
        
        # Validate provider-specific required fields
        provider_config = self.supported_providers[provider]
        for field in provider_config["required_fields"]:
            if field not in config:
                self.validation_results["errors"].append(
                    f"Missing required field for {provider}: {field}"
                )
    
    def _validate_model(self, config: Dict[str, Any]):
        """Validate model configuration"""
        model = config.get("MODEL")
        provider = config.get("SOURCE")
        
        if not model:
            self.validation_results["errors"].append("MODEL not specified")
            return
        
        if provider and provider in self.supported_providers:
            supported_models = self.supported_providers[provider]["models"]
            if model not in supported_models:
                self.validation_results["warnings"].append(
                    f"Model {model} not in supported list for {provider}: {supported_models}"
                )
        
        self.validation_results["model"] = model
    
    def _validate_api_key(self, config: Dict[str, Any]):
        """Validate API key format (without making API calls)"""
        api_key = config.get("API_KEY", "")
        provider = config.get("SOURCE")
        
        # Handle environment variable substitution
        if api_key.startswith("${") and api_key.endswith("}"):
            env_var = api_key[2:-1]
            api_key = os.environ.get(env_var, "")
            
            if not api_key:
                self.validation_results["errors"].append(f"API key environment variable {env_var} is empty")
                return
        
        if not api_key or api_key == "sk-xxxxxxxxxxxxxx":
            self.validation_results["errors"].append("API key not configured or using placeholder")
            return
        
        # Validate format based on provider
        if provider in self.supported_providers:
            pattern = self.supported_providers[provider]["api_key_pattern"]
            if not re.match(pattern, api_key):
                self.validation_results["warnings"].append(
                    f"API key format may be invalid for {provider}"
                )
        
        # Security check - ensure key is not logged
        if len(api_key) > 10:
            self.validation_results["security_check"] = "passed"
        else:
            self.validation_results["errors"].append("API key appears to be too short")
    
    def _validate_parameters(self, config: Dict[str, Any]):
        """Validate model parameters"""
        params = config.get("MODEL_PARAMETERS", {})
        
        # Temperature validation
        temp = params.get("temperature", 0.7)
        if not isinstance(temp, (int, float)) or temp < 0 or temp > 2:
            self.validation_results["warnings"].append(
                "Temperature should be between 0 and 2"
            )
        
        # Max tokens validation
        max_tokens = params.get("max_tokens", 4096)
        if not isinstance(max_tokens, int) or max_tokens < 1:
            self.validation_results["warnings"].append(
                "max_tokens should be a positive integer"
            )
        
        # Timeout validation
        timeout = params.get("timeout", 60)
        if not isinstance(timeout, int) or timeout < 1:
            self.validation_results["warnings"].append(
                "timeout should be a positive integer (seconds)"
            )
    
    def _validate_security(self, config: Dict[str, Any]):
        """Validate security settings"""
        logging_config = config.get("LOGGING", {})
        
        # Check if response logging is disabled (for privacy)
        if logging_config.get("log_responses", False):
            self.validation_results["warnings"].append(
                "Response logging is enabled - may log sensitive data"
            )
        
        # Check API base URL
        api_base = config.get("API_BASE", "")
        if api_base and not api_base.startswith("https://"):
            self.validation_results["warnings"].append(
                "API base URL should use HTTPS for security"
            )
    
    def _validate_rate_limits(self, config: Dict[str, Any]):
        """Validate rate limiting configuration"""
        rate_limits = config.get("RATE_LIMITS", {})
        
        rpm = rate_limits.get("requests_per_minute", 60)
        if not isinstance(rpm, int) or rpm < 1:
            self.validation_results["warnings"].append(
                "requests_per_minute should be a positive integer"
            )
        
        tpm = rate_limits.get("tokens_per_minute", 40000)
        if not isinstance(tpm, int) or tpm < 1:
            self.validation_results["warnings"].append(
                "tokens_per_minute should be a positive integer"
            )
    
    def _detect_capabilities(self, config: Dict[str, Any]):
        """Detect model capabilities based on model name"""
        model = config.get("MODEL", "")
        provider = config.get("SOURCE", "")
        
        capabilities = {
            "context_length": 8192,  # Default
            "supports_function_calling": False,
            "supports_vision": False,
            "estimated_cost_per_1k_input_tokens": 0.001,
            "estimated_cost_per_1k_output_tokens": 0.002
        }
        
        # Model-specific capabilities
        if "gpt-4o" in model:
            capabilities.update({
                "context_length": 128000,
                "supports_function_calling": True,
                "supports_vision": True,
                "estimated_cost_per_1k_input_tokens": 0.0025,
                "estimated_cost_per_1k_output_tokens": 0.01
            })
        elif "gpt-4" in model:
            capabilities.update({
                "context_length": 32768,
                "supports_function_calling": True,
                "estimated_cost_per_1k_input_tokens": 0.01,
                "estimated_cost_per_1k_output_tokens": 0.03
            })
        elif "claude-3-sonnet" in model:
            capabilities.update({
                "context_length": 200000,
                "supports_function_calling": True,
                "estimated_cost_per_1k_input_tokens": 0.003,
                "estimated_cost_per_1k_output_tokens": 0.015
            })
        elif "claude-3-haiku" in model:
            capabilities.update({
                "context_length": 200000,
                "estimated_cost_per_1k_input_tokens": 0.00025,
                "estimated_cost_per_1k_output_tokens": 0.00125
            })
        
        self.validation_results["capabilities"] = capabilities
    
    def create_validated_config(self, template_path: str, output_path: str) -> bool:
        """Create a validated configuration file"""
        try:
            with open(template_path, 'r') as f:
                config = yaml.safe_load(f)
            
            # Substitute environment variables
            self._substitute_env_vars(config)
            
            # Save validated configuration
            with open(output_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, indent=2)
            
            return True
            
        except Exception as e:
            self.validation_results["errors"].append(f"Error creating config: {str(e)}")
            return False
    
    def _substitute_env_vars(self, config: Dict[str, Any]):
        """Substitute environment variables in configuration"""
        def substitute_recursive(obj):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    obj[key] = substitute_recursive(value)
            elif isinstance(obj, list):
                return [substitute_recursive(item) for item in obj]
            elif isinstance(obj, str) and obj.startswith("${") and obj.endswith("}"):
                env_var = obj[2:-1]
                return os.environ.get(env_var, obj)
            return obj
        
        substitute_recursive(config)


def main():
    """Main validation function"""
    if len(sys.argv) != 3:
        print("Usage: python config_validator.py <template_path> <output_path>")
        sys.exit(1)
    
    template_path = sys.argv[1]
    output_path = sys.argv[2]
    
    validator = APIConfigValidator()
    
    # Validate the template
    results = validator.validate_config(template_path)
    
    # Create validated configuration
    success = validator.create_validated_config(template_path, output_path)
    results["config_created"] = success
    
    # Output results
    print(json.dumps(results, indent=2))
    
    # Exit with appropriate code
    if results["validation_status"] == "success" and success:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()