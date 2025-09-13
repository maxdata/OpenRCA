#!/bin/bash
set -euo pipefail

# Step: API Configuration Setup
echo "[$(date)] Starting API configuration setup..."

# Source virtual environment from step 01
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
    echo "[$(date)] Activated virtual environment"
else
    echo "Warning: Virtual environment not found, using system Python"
fi

# Create output directories
mkdir -p outputs

# Check for existing API configuration in project root
PROJECT_API_CONFIG="../../rca/api_config.yaml"
if [ -f "$PROJECT_API_CONFIG" ]; then
    echo "[$(date)] Found existing API configuration: $PROJECT_API_CONFIG"
    echo "[$(date)] Using existing configuration for validation..."
    
    # Validate existing configuration
    python inputs/config_validator.py "$PROJECT_API_CONFIG" outputs/api_config.yaml > outputs/validation_output.log 2>&1
    VALIDATION_EXIT_CODE=$?
    
    if [ $VALIDATION_EXIT_CODE -eq 0 ]; then
        echo "[$(date)] Existing API configuration is valid"
        VALIDATION_STATUS="success"
    else
        echo "[$(date)] Existing API configuration has issues"
        VALIDATION_STATUS="failed"
    fi
    
else
    echo "[$(date)] No existing API configuration found"
    echo "[$(date)] Creating configuration from template..."
    
    # Copy template as starting point
    cp inputs/api_config_template.yaml outputs/api_config.yaml
    
    echo ""
    echo "=============================================="
    echo "API CONFIGURATION REQUIRED"
    echo "=============================================="
    echo ""
    echo "Please configure your API credentials:"
    echo ""
    echo "1. Set environment variables:"
    echo "   export OPENAI_API_KEY='your-openai-key'"
    echo "   export ANTHROPIC_API_KEY='your-anthropic-key'"
    echo ""
    echo "2. Or edit the configuration file directly:"
    echo "   $PWD/outputs/api_config.yaml"
    echo ""
    echo "3. Update the following fields:"
    echo "   - SOURCE: Choose 'OpenAI' or 'Anthropic'"
    echo "   - MODEL: Select appropriate model"
    echo "   - API_KEY: Set your API key or environment variable"
    echo ""
    
    # Validate template configuration
    python inputs/config_validator.py outputs/api_config.yaml outputs/api_config_validated.yaml > outputs/validation_output.log 2>&1
    VALIDATION_EXIT_CODE=$?
    
    if [ $VALIDATION_EXIT_CODE -eq 0 ]; then
        echo "[$(date)] Template configuration structure is valid (but requires API keys)"
        VALIDATION_STATUS="template_valid"
    else
        echo "[$(date)] Template configuration validation failed"
        VALIDATION_STATUS="failed"
    fi
fi

# Extract validation results
if [ -f "outputs/validation_output.log" ]; then
    python -c "
import json
import sys

try:
    with open('outputs/validation_output.log', 'r') as f:
        content = f.read()
    
    # Find JSON content in validation output
    import re
    json_match = re.search(r'\{.*\}', content, re.DOTALL)
    if json_match:
        validation_data = json.loads(json_match.group())
        
        # Save validation results
        with open('outputs/config_validation.json', 'w') as f:
            json.dump(validation_data, f, indent=2)
        
        print('Validation results saved')
        
        # Extract capabilities
        capabilities = validation_data.get('capabilities', {})
        with open('outputs/model_capabilities.json', 'w') as f:
            json.dump(capabilities, f, indent=2)
            
        print('Model capabilities saved')
        
    else:
        print('No JSON found in validation output')
        
except Exception as e:
    print(f'Error processing validation results: {e}')
    # Create default files
    default_validation = {
        'validation_status': 'error',
        'error': 'Could not process validation results'
    }
    with open('outputs/config_validation.json', 'w') as f:
        json.dump(default_validation, f, indent=2)
    
    default_capabilities = {
        'context_length': 8192,
        'supports_function_calling': False,
        'estimated_cost_per_1k_input_tokens': 0.001
    }
    with open('outputs/model_capabilities.json', 'w') as f:
        json.dump(default_capabilities, f, indent=2)
"
fi

# Test API configuration (if credentials are available)
echo "[$(date)] Testing API configuration..."
python -c "
import yaml
import os
import json

config_path = 'outputs/api_config.yaml'
test_results = {
    'config_loaded': False,
    'provider': None,
    'model': None,
    'api_key_configured': False,
    'ready_for_use': False
}

try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    test_results['config_loaded'] = True
    test_results['provider'] = config.get('SOURCE')
    test_results['model'] = config.get('MODEL')
    
    # Check API key configuration
    api_key = config.get('API_KEY', '')
    if api_key.startswith('\${') and api_key.endswith('}'):
        env_var = api_key[2:-1]
        api_key = os.environ.get(env_var, '')
    
    if api_key and api_key != 'sk-xxxxxxxxxxxxxx':
        test_results['api_key_configured'] = True
        test_results['ready_for_use'] = True
    
    print(f'Configuration test results:')
    print(f'  Provider: {test_results[\"provider\"]}')
    print(f'  Model: {test_results[\"model\"]}')
    print(f'  API Key Configured: {test_results[\"api_key_configured\"]}')
    print(f'  Ready for Use: {test_results[\"ready_for_use\"]}')
    
except Exception as e:
    test_results['error'] = str(e)
    print(f'Configuration test failed: {e}')

# Save test results (for debugging)
with open('outputs/config_test.json', 'w') as f:
    json.dump(test_results, f, indent=2)
"

# Copy configuration to project location if validated successfully
if [ "$VALIDATION_STATUS" = "success" ] && [ -f "outputs/api_config.yaml" ]; then
    echo "[$(date)] Copying validated configuration to project location..."
    cp outputs/api_config.yaml "$PROJECT_API_CONFIG"
    echo "Updated: $PROJECT_API_CONFIG"
fi

# Provide usage instructions
echo ""
echo "[$(date)] API configuration setup completed!"
echo "Status: $VALIDATION_STATUS"
echo ""

if [ "$VALIDATION_STATUS" = "success" ]; then
    echo "✓ API configuration is ready for use"
    echo "Configuration file: outputs/api_config.yaml"
elif [ "$VALIDATION_STATUS" = "template_valid" ]; then
    echo "⚠ Configuration template is valid but requires API credentials"
    echo "Please set environment variables or edit: outputs/api_config.yaml"
    echo "Then re-run this step to validate"
else
    echo "✗ API configuration validation failed"
    echo "Check outputs/config_validation.json for details"
fi

echo ""
echo "Output files:"
echo "  - outputs/api_config.yaml: Configuration file"
echo "  - outputs/config_validation.json: Validation results"
echo "  - outputs/model_capabilities.json: Model capabilities"

# Set exit code based on validation status
if [ "$VALIDATION_STATUS" = "success" ]; then
    exit 0
elif [ "$VALIDATION_STATUS" = "template_valid" ]; then
    exit 2  # Partial success - template valid but needs credentials
else
    exit 1  # Failure
fi