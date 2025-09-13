#!/bin/bash
set -euo pipefail

echo "Testing query generation..."

# Source virtual environment
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
fi

# Test if required output files exist
REQUIRED_FILES=(
    "outputs/generation_report.json"
    "outputs/task_distribution.json"
    "outputs/query_schema.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required output file not found: $file"
        exit 1
    fi
    echo "Found: $file"
done

# Test if queries directory exists
if [ ! -d "outputs/queries" ]; then
    echo "Error: Queries directory not found"
    exit 1
fi
echo "Found: outputs/queries/"

# Test generation report structure
echo "Testing generation report structure..."
python -c "
import json
import sys

try:
    with open('outputs/generation_report.json', 'r') as f:
        report = json.load(f)
    
    # Check for required top-level keys
    if 'generation_summary' not in report:
        print('Missing generation_summary in report')
        sys.exit(1)
    
    summary = report['generation_summary']
    required_keys = ['total_queries', 'successful_generations', 'datasets_processed']
    for key in required_keys:
        if key not in summary:
            print(f'Missing required key in generation summary: {key}')
            sys.exit(1)
    
    print(f'Generation report: PASSED')
    print(f'Total queries: {summary.get(\"total_queries\", 0)}')
    print(f'Datasets processed: {len(summary.get(\"datasets_processed\", []))}')
    
except Exception as e:
    print(f'Generation report error: {e}')
    sys.exit(1)
"

# Test task distribution structure
echo "Testing task distribution structure..."
python -c "
import json
import sys

try:
    with open('outputs/task_distribution.json', 'r') as f:
        distribution = json.load(f)
    
    required_keys = ['task_distribution', 'difficulty_distribution', 'total_queries']
    for key in required_keys:
        if key not in distribution:
            print(f'Missing required key in task distribution: {key}')
            sys.exit(1)
    
    # Check difficulty levels
    diff_dist = distribution['difficulty_distribution']
    for level in ['easy', 'medium', 'hard']:
        if level not in diff_dist:
            print(f'Missing difficulty level: {level}')
            sys.exit(1)
    
    print('Task distribution: PASSED')
    
except Exception as e:
    print(f'Task distribution error: {e}')
    sys.exit(1)
"

# Test query schema structure
echo "Testing query schema structure..."
python -c "
import json
import sys

try:
    with open('outputs/query_schema.json', 'r') as f:
        schema = json.load(f)
    
    required_keys = ['description', 'columns', 'task_types']
    for key in required_keys:
        if key not in schema:
            print(f'Missing required key in schema: {key}')
            sys.exit(1)
    
    # Check column definitions
    columns = schema['columns']
    required_columns = ['task_index', 'instruction', 'scoring_points']
    for col in required_columns:
        if col not in columns:
            print(f'Missing column definition: {col}')
            sys.exit(1)
    
    print('Query schema: PASSED')
    
except Exception as e:
    print(f'Query schema error: {e}')
    sys.exit(1)
"

# Test query file format (if any exist)
echo "Testing query file formats..."
QUERY_FILES=($(find outputs/queries -name "*_query.csv" 2>/dev/null || true))

if [ ${#QUERY_FILES[@]} -eq 0 ]; then
    echo "No query files found - testing will validate structure only"
else
    python -c "
import pandas as pd
import sys
from pathlib import Path

query_files = ['${QUERY_FILES[@]}']
required_columns = ['task_index', 'instruction', 'scoring_points']

for query_file in query_files:
    try:
        df = pd.read_csv(query_file)
        
        # Check required columns
        missing_cols = [col for col in required_columns if col not in df.columns]
        if missing_cols:
            print(f'Missing columns in {query_file}: {missing_cols}')
            sys.exit(1)
        
        # Check for empty data
        if len(df) == 0:
            print(f'Empty query file: {query_file}')
            sys.exit(1)
        
        # Check task index format
        task_indices = df['task_index'].unique()
        valid_tasks = [f'task_{i}' for i in range(1, 8)]
        invalid_tasks = [task for task in task_indices if task not in valid_tasks]
        
        if invalid_tasks:
            print(f'Invalid task indices in {query_file}: {invalid_tasks}')
            sys.exit(1)
        
        print(f'Query file {Path(query_file).name}: PASSED ({len(df)} queries)')
        
    except Exception as e:
        print(f'Query file error {query_file}: {e}')
        sys.exit(1)

print('All query files: PASSED')
"
fi

# Test query generator script
echo "Testing query generator script..."
python -c "
import sys
sys.path.append('inputs')
import query_generator

try:
    # Test that main classes can be imported
    generator_class = query_generator.QueryGenerator
    print('Query generator script: PASSED')
except Exception as e:
    print(f'Query generator script error: {e}')
    sys.exit(1)
"

# Test prompt templates
echo "Testing prompt templates..."
python -c "
import sys
sys.path.append('inputs')
import prompt_templates

try:
    # Test that prompts exist
    if not hasattr(prompt_templates, 'system') or not hasattr(prompt_templates, 'user'):
        print('Missing system or user prompts')
        sys.exit(1)
    
    if not prompt_templates.system or not prompt_templates.user:
        print('Empty prompt templates')
        sys.exit(1)
    
    print('Prompt templates: PASSED')
    
except Exception as e:
    print(f'Prompt templates error: {e}')
    sys.exit(1)
"

echo "Query generation tests: PASSED"