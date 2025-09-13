# Step 02: Dataset Preparation and Validation

## Overview
This step downloads, validates, and prepares the OpenRCA telemetry datasets for analysis. It handles the large-scale telemetry data including metrics, traces, and logs from multiple systems.

## Purpose
- Download telemetry datasets from Google Drive (manual process)
- Validate dataset structure and schema compliance
- Create dataset inventory and documentation
- Prepare datasets for pipeline consumption

## Inputs
- `inputs/dataset_sources.json`: Dataset sources and expected structure
- `inputs/schema_validation.py`: Comprehensive validation script

## Outputs
- `outputs/dataset/`: Symlink to validated datasets (saves storage space)
- `outputs/validation_report.json`: Detailed validation results
- `outputs/dataset_inventory.json`: Complete dataset inventory
- `outputs/dataset_schema.json`: Schema documentation

## Dependencies
- Step 01: Environment Setup (requires Python environment)

## Requirements
- 80GB+ available storage space
- 8GB+ memory for validation processing
- Manual download from Google Drive (automated download not supported)

## Dataset Structure
The pipeline expects this directory structure:
```
dataset/
├── Telecom/
│   ├── query.csv
│   ├── record.csv
│   └── telemetry/
│       └── {YYYY_MM_DD}/
│           ├── metric/
│           ├── trace/
│           └── log/
├── Bank/
│   ├── query.csv
│   ├── record.csv
│   └── telemetry/
└── Market/
    ├── cloudbed-1/
    └── cloudbed-2/
```

## Execution
```bash
./run.sh
```

## Testing
```bash
./test.sh
```

## Manual Download Process
1. Visit: https://drive.google.com/drive/folders/1wGiEnu4OkWrjPxfx5ZTROnU37-5UDoPM
2. Download all dataset folders (Telecom, Bank, Market)
3. Extract to `dataset/` directory in project root
4. Re-run this step to validate datasets

## Key Features
- **Comprehensive Validation**: Validates file structure, schemas, and data integrity
- **Storage Optimization**: Uses symlinks to avoid data duplication
- **Flexible Handling**: Gracefully handles missing datasets
- **Detailed Reporting**: Provides comprehensive validation and inventory reports
- **Schema Documentation**: Generates complete schema documentation

## Dataset Information
- **Telecom**: ~15GB - Telecommunications system telemetry
- **Bank**: ~20GB - Banking platform telemetry  
- **Market/cloudbed-1**: ~18GB - Market system service group 1
- **Market/cloudbed-2**: ~22GB - Market system service group 2

## Validation Checks
- Directory structure compliance
- CSV file format validation
- Timestamp format and range validation
- Schema compliance for all telemetry files
- Data completeness and consistency checks

## Common Issues
1. **Storage Space**: Ensure sufficient space before download
2. **Download Timeout**: Google Drive may timeout on large files
3. **File Permissions**: Ensure read/write permissions on dataset directory
4. **Memory Usage**: Large datasets may require more memory for validation

## Timezone Handling
All datasets use UTC+8 timezone (Asia/Shanghai) for timestamp consistency.