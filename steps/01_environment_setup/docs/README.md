# Step 01: Environment Setup and Dependencies

## Overview
This step sets up the Python environment and installs all required dependencies for the OpenRCA pipeline. It creates a virtual environment, installs packages, and validates the installation.

## Purpose
- Create isolated Python environment for OpenRCA
- Install all required Python packages from requirements.txt
- Validate installation and package versions
- Set up IPython kernel for RCA agent execution

## Inputs
- `inputs/requirements.txt`: Original OpenRCA dependencies

## Outputs
- `outputs/environment_check.json`: Validation results and package inventory
- `outputs/logs/`: Installation and validation logs
- `venv/`: Python virtual environment

## Dependencies
None - this is the first step in the pipeline

## Requirements
- Python 3.10 or higher
- pip package manager
- git (for repository management)
- At least 2GB memory for package installation

## Execution
```bash
./run.sh
```

## Testing
```bash
./test.sh
```

## Key Features
- **Version Validation**: Ensures Python 3.10+ is available
- **Virtual Environment**: Creates isolated environment for dependencies
- **Package Verification**: Validates all required packages are installed correctly
- **Import Testing**: Tests core functionality imports
- **Comprehensive Logging**: Detailed logs for troubleshooting

## Common Issues
1. **Python Version**: Ensure Python 3.10+ is installed and in PATH
2. **Virtual Environment**: If venv creation fails, check permissions
3. **Package Conflicts**: Clear pip cache if installation fails
4. **Memory**: Ensure sufficient memory for package compilation

## Validation Checks
- Python version >= 3.10
- All required packages installed
- Core imports work correctly
- IPython kernel functionality available