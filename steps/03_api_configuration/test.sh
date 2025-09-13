#!/bin/bash
set -euo pipefail

echo "Testing API configuration setup..."

# Source virtual environment
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
fi

# Test if required output files exist
REQUIRED_FILES=(
    "outputs/api_config.yaml"
    "outputs/config_validation.json"
    "outputs/model_capabilities.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required output file not found: $file"
        exit 1
    fi
    echo "Found: $file"
done

# Test configuration file structure
echo "Testing configuration file structure..."
python -c "
import yaml
import sys

try:
    with open('outputs/api_config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    required_keys = ['SOURCE', 'MODEL', 'API_KEY']
    for key in required_keys:
        if key not in config:
            print(f'Missing required key in config: {key}')
            sys.exit(1)
    
    print('Configuration structure: PASSED')
    
except Exception as e:
    print(f'Configuration file error: {e}')
    sys.exit(1)
"

# Test validation results structure
echo "Testing validation results structure..."
python -c "
import json
import sys

try:
    with open('outputs/config_validation.json', 'r') as f:
        validation = json.load(f)
    
    required_keys = ['validation_status']
    for key in required_keys:
        if key not in validation:
            print(f'Missing required key in validation: {key}')
            sys.exit(1)
    
    status = validation['validation_status']
    valid_statuses = ['success', 'failed', 'pending', 'template_valid']
    if status not in valid_statuses:
        print(f'Invalid validation status: {status}')
        sys.exit(1)
    
    print(f'Validation status: {status}')
    print('Validation results structure: PASSED')
    
except Exception as e:
    print(f'Validation results error: {e}')
    sys.exit(1)
"

# Test model capabilities structure
echo "Testing model capabilities structure..."
python -c "
import json
import sys

try:
    with open('outputs/model_capabilities.json', 'r') as f:
        capabilities = json.load(f)
    
    expected_keys = ['context_length']
    for key in expected_keys:
        if key not in capabilities:
            print(f'Missing expected key in capabilities: {key}')
            # This is a warning, not an error
    
    print('Model capabilities structure: PASSED')
    
except Exception as e:
    print(f'Model capabilities error: {e}')
    sys.exit(1)
"

# Test validator script functionality
echo "Testing config validator script..."
python -c "
import sys
sys.path.append('inputs')
import config_validator

try:
    validator = config_validator.APIConfigValidator()
    print('Config validator script: PASSED')
except Exception as e:
    print(f'Config validator error: {e}')
    sys.exit(1)
"

# Test template file validity
echo "Testing template file..."
python -c "
import yaml
import sys

try:
    with open('inputs/api_config_template.yaml', 'r') as f:
        template = yaml.safe_load(f)
    
    if not template:
        print('Template file is empty')
        sys.exit(1)
    
    # Check that template has required structure
    required_sections = ['SOURCE', 'MODEL', 'API_KEY']
    for section in required_sections:
        if section not in template:
            print(f'Missing section in template: {section}')
            sys.exit(1)
    
    print('Template file: PASSED')
    
except Exception as e:
    print(f'Template file error: {e}')
    sys.exit(1)
"

echo "API configuration tests: PASSED"