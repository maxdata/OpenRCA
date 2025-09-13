#!/bin/bash
set -euo pipefail

echo "Testing dataset preparation..."

# Source virtual environment
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
fi

# Test if required output files exist
REQUIRED_FILES=(
    "outputs/validation_report.json"
    "outputs/dataset_inventory.json" 
    "outputs/dataset_schema.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required output file not found: $file"
        exit 1
    fi
    echo "Found: $file"
done

# Test validation report structure
echo "Testing validation report structure..."
python -c "
import json
import sys

with open('outputs/validation_report.json', 'r') as f:
    report = json.load(f)

required_keys = ['validation_status']
for key in required_keys:
    if key not in report:
        print(f'Missing required key in validation report: {key}')
        sys.exit(1)

status = report['validation_status']
if status not in ['success', 'partial', 'failed', 'datasets_not_found']:
    print(f'Invalid validation status: {status}')
    sys.exit(1)

print(f'Validation status: {status}')
"

# Test dataset inventory structure
echo "Testing dataset inventory structure..."
python -c "
import json
import sys

with open('outputs/dataset_inventory.json', 'r') as f:
    inventory = json.load(f)

required_keys = ['total_datasets', 'available_datasets', 'missing_datasets']
for key in required_keys:
    if key not in inventory:
        print(f'Missing required key in inventory: {key}')
        sys.exit(1)

print(f'Total datasets: {inventory[\"total_datasets\"]}')
print(f'Available: {len(inventory[\"available_datasets\"])}')
print(f'Missing: {len(inventory[\"missing_datasets\"])}')
"

# Test dataset schema structure
echo "Testing dataset schema structure..."
python -c "
import json
import sys

with open('outputs/dataset_schema.json', 'r') as f:
    schema = json.load(f)

required_keys = ['description', 'datasets', 'telemetry_files']
for key in required_keys:
    if key not in schema:
        print(f'Missing required key in schema: {key}')
        sys.exit(1)

# Check expected datasets are defined
expected_datasets = ['Telecom', 'Bank', 'Market']
for dataset in expected_datasets:
    if dataset not in schema['datasets']:
        print(f'Missing dataset definition: {dataset}')
        sys.exit(1)

print('Dataset schema validation: PASSED')
"

# Test dataset symlink if datasets are available  
if [ -L "outputs/dataset" ]; then
    echo "Dataset symlink found: outputs/dataset"
    if [ -d "outputs/dataset" ]; then
        echo "Dataset symlink is valid"
    else
        echo "Warning: Dataset symlink is broken"
    fi
else
    echo "No dataset symlink found (expected if datasets not downloaded)"
fi

# Test schema validation script
echo "Testing schema validation script..."
python -c "
import sys
sys.path.append('inputs')
import schema_validation

# Test that the validator class can be imported and instantiated
try:
    validator = schema_validation.DatasetValidator('/tmp', {})
    print('Schema validation script: PASSED')
except Exception as e:
    print(f'Schema validation script error: {e}')
    sys.exit(1)
"

echo "Dataset preparation tests: PASSED"