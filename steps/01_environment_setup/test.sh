#!/bin/bash
set -euo pipefail

echo "Testing environment setup..."

# Test if virtual environment was created
if [ ! -d "venv" ]; then
    echo "Error: Virtual environment not created"
    exit 1
fi

# Test if environment check file exists
if [ ! -f "outputs/environment_check.json" ]; then
    echo "Error: Environment check file not found"
    exit 1
fi

# Validate environment check results
python -c "
import json
import sys

with open('outputs/environment_check.json', 'r') as f:
    results = json.load(f)

if results['validation_status'] != 'success':
    print('Environment validation failed')
    print('Missing packages:', results.get('missing_packages', []))
    print('Version mismatches:', results.get('version_mismatches', []))
    sys.exit(1)

print('Environment validation: PASSED')
print('Required packages are installed correctly')
"

# Test activation and imports
source venv/bin/activate
python -c "
import pandas as pd
import anthropic  
import openai
import yaml
from loguru import logger
from IPython.terminal.embed import InteractiveShellEmbed
print('Core imports: PASSED')
"

echo "Environment setup tests: PASSED"