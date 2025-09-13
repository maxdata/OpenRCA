#!/bin/bash
set -euo pipefail

# Step: Query Generation and Task Specification
echo "[$(date)] Starting query generation..."

# Source virtual environment from step 01
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
    echo "[$(date)] Activated virtual environment"
else
    echo "Warning: Virtual environment not found, using system Python"
fi

# Create output directories
mkdir -p outputs/queries outputs/logs

# Check dependencies
DATASET_ROOT="../02_dataset_preparation/outputs/dataset"
API_CONFIG="../03_api_configuration/outputs/api_config.yaml"

if [ ! -d "$DATASET_ROOT" ]; then
    echo "Error: Dataset directory not found: $DATASET_ROOT"
    echo "Please ensure step 02 (dataset preparation) completed successfully"
    exit 1
fi

if [ ! -f "$API_CONFIG" ]; then
    echo "Error: API configuration not found: $API_CONFIG"
    echo "Please ensure step 03 (API configuration) completed successfully"
    exit 1
fi

echo "[$(date)] Dependencies validated"

# Check API configuration is ready
echo "[$(date)] Validating API configuration..."
python -c "
import yaml
import os
import sys

try:
    with open('$API_CONFIG', 'r') as f:
        config = yaml.safe_load(f)
    
    # Check API key is configured
    api_key = config.get('API_KEY', '')
    if api_key.startswith('\${') and api_key.endswith('}'):
        env_var = api_key[2:-1]
        api_key = os.environ.get(env_var, '')
    
    if not api_key or api_key == 'sk-xxxxxxxxxxxxxx':
        print('API key not configured. Please configure API credentials in step 03.')
        sys.exit(1)
    
    print('API configuration is ready')
    
except Exception as e:
    print(f'API configuration validation failed: {e}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "API configuration validation failed. Please complete step 03 first."
    exit 1
fi

# Check for existing queries (to avoid regeneration)
EXISTING_QUERIES=0
for dataset in "Telecom" "Bank" "Market_cloudbed-1" "Market_cloudbed-2"; do
    if [ -f "outputs/queries/${dataset}_query.csv" ]; then
        EXISTING_QUERIES=$((EXISTING_QUERIES + 1))
    fi
done

if [ $EXISTING_QUERIES -gt 0 ]; then
    echo ""
    echo "Found $EXISTING_QUERIES existing query files."
    read -p "Regenerate queries? This will overwrite existing files. (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing queries. Validating structure..."
        
        # Validate existing queries
        python -c "
import pandas as pd
import json
import os
from pathlib import Path

validation_results = {
    'existing_queries': True,
    'valid_files': [],
    'invalid_files': [],
    'total_queries': 0,
    'task_distribution': {}
}

query_dir = Path('outputs/queries')
for query_file in query_dir.glob('*_query.csv'):
    try:
        df = pd.read_csv(query_file)
        required_cols = ['task_index', 'instruction', 'scoring_points']
        
        if all(col in df.columns for col in required_cols):
            validation_results['valid_files'].append(query_file.name)
            validation_results['total_queries'] += len(df)
            
            # Count task distribution
            for task in df['task_index']:
                if task not in validation_results['task_distribution']:
                    validation_results['task_distribution'][task] = 0
                validation_results['task_distribution'][task] += 1
        else:
            validation_results['invalid_files'].append(query_file.name)
            
    except Exception as e:
        validation_results['invalid_files'].append(f'{query_file.name}: {str(e)}')

# Save validation results
with open('outputs/generation_report.json', 'w') as f:
    json.dump(validation_results, f, indent=2)

print(f'Validated {len(validation_results[\"valid_files\"])} query files')
print(f'Total queries: {validation_results[\"total_queries\"]}')

if validation_results['invalid_files']:
    print(f'Invalid files: {validation_results[\"invalid_files\"]}')
    exit(1)
"
        echo "[$(date)] Existing queries validated successfully"
        exit 0
    fi
fi

# Run query generation
echo "[$(date)] Running query generation..."
cd inputs

python query_generator.py \
    --dataset_root "$DATASET_ROOT" \
    --api_config "../$API_CONFIG" \
    --task_spec "task_specification.json" \
    --output_dir "../outputs/queries" \
    --report_file "../outputs/generation_report.json" \
    2>&1 | tee ../outputs/logs/generation.log

GENERATION_EXIT_CODE=${PIPESTATUS[0]}
cd ..

if [ $GENERATION_EXIT_CODE -eq 0 ]; then
    echo "[$(date)] Query generation: SUCCESS"
    GENERATION_STATUS="success"
elif [ $GENERATION_EXIT_CODE -eq 2 ]; then
    echo "[$(date)] Query generation: PARTIAL SUCCESS"
    GENERATION_STATUS="partial"
else
    echo "[$(date)] Query generation: FAILED"
    GENERATION_STATUS="failed"
fi

# Analyze task distribution
echo "[$(date)] Analyzing task distribution..."
python -c "
import json
import pandas as pd
from pathlib import Path

# Load generation report
try:
    with open('outputs/generation_report.json', 'r') as f:
        report = json.load(f)
    
    # Calculate difficulty distribution
    generation_summary = report.get('generation_summary', {})
    task_dist = generation_summary.get('task_distribution', {})
    
    difficulty_dist = {
        'easy': 0,    # tasks 1-3
        'medium': 0,  # tasks 4-6  
        'hard': 0     # task 7
    }
    
    for task, count in task_dist.items():
        task_num = int(task.split('_')[1])
        if task_num <= 3:
            difficulty_dist['easy'] += count
        elif task_num <= 6:
            difficulty_dist['medium'] += count
        else:
            difficulty_dist['hard'] += count
    
    # Save task distribution analysis
    distribution_analysis = {
        'task_distribution': task_dist,
        'difficulty_distribution': difficulty_dist,
        'total_queries': sum(task_dist.values()),
        'datasets_processed': generation_summary.get('datasets_processed', []),
        'generation_stats': {
            'successful_generations': generation_summary.get('successful_generations', 0),
            'failed_generations': generation_summary.get('failed_generations', 0),
            'multi_failure_queries': generation_summary.get('multi_failure_queries', 0)
        }
    }
    
    with open('outputs/task_distribution.json', 'w') as f:
        json.dump(distribution_analysis, f, indent=2)
    
    print('Task distribution analysis:')
    print(f'  Easy (tasks 1-3): {difficulty_dist[\"easy\"]} queries')
    print(f'  Medium (tasks 4-6): {difficulty_dist[\"medium\"]} queries')
    print(f'  Hard (task 7): {difficulty_dist[\"hard\"]} queries')
    print(f'  Total: {distribution_analysis[\"total_queries\"]} queries')
    
except Exception as e:
    print(f'Error analyzing task distribution: {e}')
"

# Create query schema documentation
echo "[$(date)] Creating query schema documentation..."
cat > outputs/query_schema.json << 'EOF'
{
  "description": "OpenRCA generated query schema",
  "file_format": "CSV",
  "columns": {
    "task_index": {
      "type": "string",
      "description": "Task type identifier (task_1 through task_7)",
      "example": "task_7"
    },
    "instruction": {
      "type": "string", 
      "description": "Generated DevOps failure diagnosis issue description",
      "example": "The system experienced failures during the specified time range..."
    },
    "scoring_points": {
      "type": "string",
      "description": "Evaluation criteria for the query response",
      "example": "The only root cause occurrence time is within 1 minutes of 2021-03-05 14:23:15\\nThe only predicted root cause component is apache01\\n..."
    }
  },
  "task_types": {
    "task_1": "Time prediction only",
    "task_2": "Reason prediction only",
    "task_3": "Component prediction only", 
    "task_4": "Time + Reason prediction",
    "task_5": "Time + Component prediction",
    "task_6": "Component + Reason prediction",
    "task_7": "Full prediction (Time + Component + Reason)"
  },
  "difficulty_levels": {
    "easy": "tasks 1-3 (single element prediction)",
    "medium": "tasks 4-6 (two element prediction)", 
    "hard": "task 7 (full prediction)"
  },
  "timezone": "UTC+8 (Asia/Shanghai)",
  "multi_failure_handling": "Queries may contain multiple failures within same 30-minute window"
}
EOF

# Validate generated queries
echo "[$(date)] Validating generated queries..."
python -c "
import pandas as pd
import json
from pathlib import Path

validation_results = {
    'validation_status': 'pending',
    'files_validated': [],
    'validation_errors': [],
    'total_queries': 0,
    'column_validation': {},
    'content_validation': {}
}

query_dir = Path('outputs/queries')
required_columns = ['task_index', 'instruction', 'scoring_points']

for query_file in query_dir.glob('*_query.csv'):
    try:
        df = pd.read_csv(query_file)
        file_validation = {
            'file': query_file.name,
            'rows': len(df),
            'columns': list(df.columns),
            'missing_columns': [],
            'empty_values': 0
        }
        
        # Check required columns
        for col in required_columns:
            if col not in df.columns:
                file_validation['missing_columns'].append(col)
        
        # Check for empty values
        file_validation['empty_values'] = df.isnull().sum().sum()
        
        # Check task index format
        task_indices = df['task_index'].unique()
        valid_tasks = [f'task_{i}' for i in range(1, 8)]
        invalid_tasks = [task for task in task_indices if task not in valid_tasks]
        
        if invalid_tasks:
            file_validation['invalid_task_indices'] = invalid_tasks
        
        validation_results['files_validated'].append(file_validation)
        validation_results['total_queries'] += len(df)
        
    except Exception as e:
        validation_results['validation_errors'].append(f'{query_file.name}: {str(e)}')

# Determine validation status
if validation_results['validation_errors']:
    validation_results['validation_status'] = 'failed'
elif any(fv.get('missing_columns') or fv.get('invalid_task_indices') for fv in validation_results['files_validated']):
    validation_results['validation_status'] = 'partial'
else:
    validation_results['validation_status'] = 'success'

print(f'Query validation status: {validation_results[\"validation_status\"]}')
print(f'Total queries validated: {validation_results[\"total_queries\"]}')

if validation_results['validation_errors']:
    print(f'Validation errors: {validation_results[\"validation_errors\"]}')

# Update generation report with validation results
try:
    with open('outputs/generation_report.json', 'r') as f:
        report = json.load(f)
    report['validation_results'] = validation_results
    
    with open('outputs/generation_report.json', 'w') as f:
        json.dump(report, f, indent=2)
except:
    pass
"

echo "[$(date)] Query generation completed!"
echo "Generation status: $GENERATION_STATUS"
echo ""
echo "Output files:"
echo "  - outputs/queries/: Generated query files"
echo "  - outputs/generation_report.json: Detailed generation report"
echo "  - outputs/task_distribution.json: Task distribution analysis"
echo "  - outputs/query_schema.json: Query schema documentation"

# Set exit code based on generation status
if [ "$GENERATION_STATUS" = "success" ]; then
    exit 0
elif [ "$GENERATION_STATUS" = "partial" ]; then
    exit 2  # Partial success
else
    exit 1  # Failure
fi