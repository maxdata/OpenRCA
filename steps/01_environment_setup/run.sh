#!/bin/bash
set -euo pipefail

# Step: Environment Setup and Dependencies
echo "[$(date)] Starting environment setup..."

# Create output directories
mkdir -p outputs/logs

# Validate Python version
PYTHON_VERSION=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
MAJOR_VERSION=$(echo $PYTHON_VERSION | cut -d. -f1)
MINOR_VERSION=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$MAJOR_VERSION" -lt 3 ] || ([ "$MAJOR_VERSION" -eq 3 ] && [ "$MINOR_VERSION" -lt 10 ]); then
    echo "Error: Python 3.10+ required, found $PYTHON_VERSION"
    exit 1
fi

echo "[$(date)] Python version check passed: $PYTHON_VERSION"

# Create virtual environment if needed
if [ ! -d "venv" ]; then
    echo "[$(date)] Creating virtual environment..."
    python -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo "[$(date)] Upgrading pip..."
pip install --upgrade pip > outputs/logs/pip_upgrade.log 2>&1

# Install requirements
echo "[$(date)] Installing requirements..."
pip install -r inputs/requirements.txt > outputs/logs/pip_install.log 2>&1

# Additional system-specific packages for IPython kernel
echo "[$(date)] Installing additional packages for RCA agent..."
pip install ipython jupyter > outputs/logs/additional_packages.log 2>&1

# Validate installation
echo "[$(date)] Validating installation..."
python -c "
import json
import sys
import pkg_resources

# Get installed packages
installed_packages = {pkg.project_name: pkg.version for pkg in pkg_resources.working_set}

# Required packages validation
required_packages = {
    'anthropic': '0.39.0',
    'openai': '1.54.3', 
    'pandas': None,  # Version can vary (>=2.0.0)
    'loguru': '0.7.2',
    'PyYAML': '6.0.2',
    'ipython': None,  # Version can vary
    'jupyter': None   # Version can vary
}

validation_results = {
    'python_version': sys.version,
    'installed_packages': installed_packages,
    'validation_status': 'success',
    'missing_packages': [],
    'version_mismatches': []
}

for pkg, expected_version in required_packages.items():
    if pkg not in installed_packages:
        validation_results['missing_packages'].append(pkg)
        validation_results['validation_status'] = 'failed'
    elif expected_version and installed_packages[pkg] != expected_version:
        validation_results['version_mismatches'].append({
            'package': pkg,
            'expected': expected_version,
            'actual': installed_packages[pkg]
        })

# Save validation results
with open('outputs/environment_check.json', 'w') as f:
    json.dump(validation_results, f, indent=2)

if validation_results['validation_status'] == 'failed':
    print('Environment validation failed!')
    sys.exit(1)
else:
    print('Environment validation passed!')
"

# Test imports for core functionality
echo "[$(date)] Testing core imports..."
python -c "
import pandas as pd
import anthropic
import openai
import yaml
from loguru import logger
from IPython.terminal.embed import InteractiveShellEmbed
print('All core imports successful!')
" > outputs/logs/import_test.log 2>&1

echo "[$(date)] Environment setup completed successfully!"
echo "Virtual environment: $(pwd)/venv"
echo "Validation results: $(pwd)/outputs/environment_check.json"