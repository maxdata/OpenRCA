#!/bin/bash
set -euo pipefail

# Step: Dataset Preparation and Validation
echo "[$(date)] Starting dataset preparation..."

# Source virtual environment from previous step
if [ -f "../01_environment_setup/venv/bin/activate" ]; then
    source ../01_environment_setup/venv/bin/activate
    echo "[$(date)] Activated virtual environment"
else
    echo "Warning: Virtual environment not found, using system Python"
fi

# Create output directories
mkdir -p outputs/dataset outputs/logs

# Check if dataset directory exists in project root
DATASET_ROOT="../../dataset"
if [ ! -d "$DATASET_ROOT" ]; then
    echo "[$(date)] Creating dataset directory..."
    mkdir -p "$DATASET_ROOT"
fi

# Check for existing datasets
echo "[$(date)] Checking for existing datasets..."
DATASETS_FOUND=0

for dataset in "Telecom" "Bank" "Market"; do
    if [ -d "$DATASET_ROOT/$dataset" ]; then
        echo "Found dataset: $dataset"
        DATASETS_FOUND=$((DATASETS_FOUND + 1))
    else
        echo "Missing dataset: $dataset"
    fi
done

if [ $DATASETS_FOUND -eq 0 ]; then
    echo ""
    echo "=============================================="
    echo "DATASET DOWNLOAD REQUIRED"
    echo "=============================================="
    echo ""
    echo "No datasets found. Please download the datasets from:"
    echo "https://drive.google.com/drive/folders/1wGiEnu4OkWrjPxfx5ZTROnU37-5UDoPM"
    echo ""
    echo "Expected directory structure:"
    echo "$DATASET_ROOT/"
    echo "├── Telecom/"
    echo "│   ├── query.csv"
    echo "│   ├── record.csv"
    echo "│   └── telemetry/"
    echo "├── Bank/"
    echo "│   ├── query.csv"
    echo "│   ├── record.csv"
    echo "│   └── telemetry/"
    echo "└── Market/"
    echo "    ├── cloudbed-1/"
    echo "    └── cloudbed-2/"
    echo ""
    echo "After downloading, re-run this step to validate the datasets."
    echo ""
    
    # Create placeholder validation report
    cat > outputs/validation_report.json << EOF
{
  "validation_status": "datasets_not_found",
  "message": "Datasets need to be manually downloaded from Google Drive",
  "download_url": "https://drive.google.com/drive/folders/1wGiEnu4OkWrjPxfx5ZTROnU37-5UDoPM",
  "required_action": "Download datasets and place in dataset/ directory"
}
EOF
    
    # Create empty dataset inventory
    cat > outputs/dataset_inventory.json << EOF
{
  "total_datasets": 0,
  "available_datasets": [],
  "missing_datasets": ["Telecom", "Bank", "Market/cloudbed-1", "Market/cloudbed-2"],
  "total_size_gb": 0
}
EOF
    
    echo "Created placeholder validation files. Please download datasets and re-run."
    echo "[$(date)] Dataset preparation completed - MANUAL DOWNLOAD REQUIRED"
    exit 0
fi

echo "[$(date)] Found $DATASETS_FOUND datasets, proceeding with validation..."

# Run schema validation
echo "[$(date)] Running schema validation..."
python inputs/schema_validation.py "$DATASET_ROOT" inputs/dataset_sources.json > outputs/logs/validation_output.log 2>&1
VALIDATION_EXIT_CODE=$?

# Process validation results
if [ $VALIDATION_EXIT_CODE -eq 0 ]; then
    echo "[$(date)] Dataset validation: SUCCESS"
    VALIDATION_STATUS="success"
elif [ $VALIDATION_EXIT_CODE -eq 2 ]; then
    echo "[$(date)] Dataset validation: PARTIAL SUCCESS"
    VALIDATION_STATUS="partial"
else
    echo "[$(date)] Dataset validation: FAILED"
    VALIDATION_STATUS="failed"
fi

# Extract validation results from log
if [ -f "outputs/logs/validation_output.log" ]; then
    # Try to extract JSON from validation output
    python -c "
import json
import sys

try:
    with open('outputs/logs/validation_output.log', 'r') as f:
        content = f.read()
    
    # Find JSON content in the output
    import re
    json_match = re.search(r'\{.*\}', content, re.DOTALL)
    if json_match:
        validation_data = json.loads(json_match.group())
        
        # Save validation report
        with open('outputs/validation_report.json', 'w') as f:
            json.dump(validation_data, f, indent=2)
        
        print('Validation report saved successfully')
    else:
        print('No JSON found in validation output')
        
except Exception as e:
    print(f'Error processing validation results: {e}')
    sys.exit(1)
" || echo "Warning: Could not process validation results"
fi

# Create dataset inventory
echo "[$(date)] Creating dataset inventory..."
python -c "
import json
import os
from pathlib import Path

dataset_root = Path('../../dataset')
inventory = {
    'total_datasets': 0,
    'available_datasets': [],
    'missing_datasets': [],
    'total_size_gb': 0
}

expected_datasets = ['Telecom', 'Bank', 'Market/cloudbed-1', 'Market/cloudbed-2']

for dataset in expected_datasets:
    dataset_path = dataset_root / dataset
    if dataset_path.exists():
        inventory['available_datasets'].append(dataset)
        inventory['total_datasets'] += 1
        
        # Calculate size
        total_size = 0
        for file_path in dataset_path.rglob('*'):
            if file_path.is_file():
                total_size += file_path.stat().st_size
        
        size_gb = total_size / (1024**3)
        inventory['total_size_gb'] += size_gb
        
    else:
        inventory['missing_datasets'].append(dataset)

# Save inventory
with open('outputs/dataset_inventory.json', 'w') as f:
    json.dump(inventory, f, indent=2)

print(f'Dataset inventory created: {inventory[\"total_datasets\"]} datasets found')
"

# Copy validated datasets to outputs (create symlinks to save space)
echo "[$(date)] Creating dataset symlinks..."
if [ -d "$DATASET_ROOT" ]; then
    # Remove existing symlink if it exists
    if [ -L "outputs/dataset" ]; then
        rm outputs/dataset
    fi
    
    # Create symlink to original dataset directory
    ln -sf "$(realpath $DATASET_ROOT)" outputs/dataset
    echo "Created symlink: outputs/dataset -> $DATASET_ROOT"
fi

# Create dataset schema file
echo "[$(date)] Generating dataset schema documentation..."
cat > outputs/dataset_schema.json << 'EOF'
{
  "description": "OpenRCA telemetry dataset schema",
  "datasets": {
    "Telecom": {
      "description": "Telecom system telemetry data",
      "structure": {
        "query.csv": "Task queries and instructions",
        "record.csv": "Ground truth failure records", 
        "telemetry/": "Time-series telemetry data organized by date"
      }
    },
    "Bank": {
      "description": "Banking platform telemetry data",
      "structure": {
        "query.csv": "Task queries and instructions",
        "record.csv": "Ground truth failure records",
        "telemetry/": "Time-series telemetry data organized by date"
      }
    },
    "Market": {
      "cloudbed-1": {
        "description": "Market system cloudbed service group 1",
        "structure": {
          "query.csv": "Task queries and instructions", 
          "record.csv": "Ground truth failure records",
          "telemetry/": "Time-series telemetry data organized by date"
        }
      },
      "cloudbed-2": {
        "description": "Market system cloudbed service group 2",
        "structure": {
          "query.csv": "Task queries and instructions",
          "record.csv": "Ground truth failure records", 
          "telemetry/": "Time-series telemetry data organized by date"
        }
      }
    }
  },
  "telemetry_files": {
    "metric_app.csv": {
      "columns": ["timestamp", "rr", "sr", "cnt", "mrt", "tc"],
      "description": "Application-level metrics",
      "timestamp_unit": "seconds"
    },
    "metric_container.csv": {
      "columns": ["timestamp", "cmdb_id", "kpi_name", "value"],
      "description": "Container and system metrics",
      "timestamp_unit": "seconds"
    },
    "trace_span.csv": {
      "columns": ["timestamp", "cmdb_id", "parent_id", "span_id", "trace_id", "duration"],
      "description": "Distributed tracing spans",
      "timestamp_unit": "milliseconds"
    },
    "log_service.csv": {
      "columns": ["log_id", "timestamp", "cmdb_id", "log_name", "value"],
      "description": "Service logs and events",
      "timestamp_unit": "seconds"
    }
  },
  "timezone": "UTC+8 (Asia/Shanghai)"
}
EOF

echo "[$(date)] Dataset preparation completed!"
echo "Validation status: $VALIDATION_STATUS"
echo "Dataset inventory: outputs/dataset_inventory.json"
echo "Validation report: outputs/validation_report.json"
echo "Dataset schema: outputs/dataset_schema.json"

if [ "$VALIDATION_STATUS" = "failed" ]; then
    echo "Dataset validation failed. Check outputs/logs/ for details."
    exit 1
elif [ "$VALIDATION_STATUS" = "partial" ]; then
    echo "Dataset validation partially successful. Some datasets may be missing."
    exit 0
else
    echo "Dataset validation successful!"
    exit 0
fi