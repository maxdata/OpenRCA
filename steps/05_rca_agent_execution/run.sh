#!/bin/bash
set -euo pipefail

# Step: RCA Agent Execution
echo "[$(date)] Starting RCA agent execution..."

# Source virtual environment
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
fi

# Create output directories
mkdir -p outputs/{predictions,trajectories,monitoring,logs}

# Check dependencies
QUERIES_DIR="../04_query_generation/outputs/queries"
DATASET_ROOT="../02_dataset_preparation/outputs/dataset"
API_CONFIG="../03_api_configuration/outputs/api_config.yaml"

for dep in "$QUERIES_DIR" "$DATASET_ROOT" "$API_CONFIG"; do
    if [ ! -e "$dep" ]; then
        echo "Error: Dependency not found: $dep"
        exit 1
    fi
done

echo "[$(date)] Dependencies validated"

# Execute RCA agent for each dataset
DATASETS=("Telecom" "Bank" "Market_cloudbed-1" "Market_cloudbed-2")
EXECUTION_RESULTS=()

for dataset in "${DATASETS[@]}"; do
    echo "[$(date)] Processing dataset: $dataset"
    
    # Convert dataset name format
    DATASET_PATH=$(echo "$dataset" | sed 's/_/\//')
    QUERY_FILE="${QUERIES_DIR}/${dataset}_query.csv"
    
    if [ ! -f "$QUERY_FILE" ]; then
        echo "Warning: Query file not found for $dataset, skipping"
        continue
    fi
    
    # Create dataset-specific output directories
    mkdir -p "outputs/predictions/$dataset"
    mkdir -p "outputs/trajectories/$dataset" 
    mkdir -p "outputs/monitoring/$dataset"
    
    # Run RCA agent
    python inputs/agent_runner.py \
        --dataset "$DATASET_PATH" \
        --query_file "$QUERY_FILE" \
        --dataset_root "$DATASET_ROOT" \
        --api_config "$API_CONFIG" \
        --output_dir "outputs" \
        --dataset_name "$dataset" \
        2>&1 | tee "outputs/logs/${dataset}_execution.log"
    
    EXECUTION_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $EXECUTION_EXIT_CODE -eq 0 ]; then
        echo "[$(date)] $dataset execution: SUCCESS"
        EXECUTION_RESULTS+=("$dataset:success")
    else
        echo "[$(date)] $dataset execution: FAILED"
        EXECUTION_RESULTS+=("$dataset:failed")
    fi
done

# Generate execution report
echo "[$(date)] Generating execution report..."
python -c "
import json
import os
from pathlib import Path

execution_results = ['${EXECUTION_RESULTS[@]}']
datasets = ['${DATASETS[@]}']

report = {
    'execution_summary': {
        'total_datasets': len(datasets),
        'successful_executions': 0,
        'failed_executions': 0,
        'dataset_results': {}
    },
    'output_files': {
        'predictions': [],
        'trajectories': [],
        'monitoring': []
    }
}

# Process execution results
for result in execution_results:
    if ':' in result:
        dataset, status = result.split(':')
        report['execution_summary']['dataset_results'][dataset] = status
        if status == 'success':
            report['execution_summary']['successful_executions'] += 1
        else:
            report['execution_summary']['failed_executions'] += 1

# Count output files
for output_type in ['predictions', 'trajectories', 'monitoring']:
    output_dir = Path(f'outputs/{output_type}')
    if output_dir.exists():
        files = list(output_dir.rglob('*'))
        report['output_files'][output_type] = [str(f) for f in files if f.is_file()]

with open('outputs/execution_report.json', 'w') as f:
    json.dump(report, f, indent=2)

print('Execution report generated')
"

echo "[$(date)] RCA agent execution completed!"
echo "Results: ${EXECUTION_RESULTS[@]}"
echo "Execution report: outputs/execution_report.json"