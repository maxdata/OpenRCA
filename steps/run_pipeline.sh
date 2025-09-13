#!/bin/bash
set -euo pipefail

# OpenRCA Pipeline Execution Script
echo "=========================================="
echo "OpenRCA Root Cause Analysis Pipeline"
echo "=========================================="
echo ""

# Configuration
PIPELINE_START_TIME=$(date)
STEPS_DIR="$(pwd)"
LOG_DIR="$STEPS_DIR/pipeline_logs"
STEP_ORDER=(
    "01_environment_setup"
    "02_dataset_preparation" 
    "03_api_configuration"
    "04_query_generation"
    "05_rca_agent_execution"
    "06_baseline_execution"
    "07_evaluation_reporting"
    "08_performance_analysis"
)

# Create pipeline log directory
mkdir -p "$LOG_DIR"

# Pipeline status tracking
PIPELINE_STATUS=()
FAILED_STEPS=()

# Function to run a single step
run_step() {
    local step_name="$1"
    local step_dir="$STEPS_DIR/$step_name"
    local log_file="$LOG_DIR/${step_name}.log"
    
    echo "[$(date)] Starting step: $step_name"
    
    if [ ! -d "$step_dir" ]; then
        echo "Error: Step directory not found: $step_dir"
        PIPELINE_STATUS+=("$step_name:missing")
        FAILED_STEPS+=("$step_name")
        return 1
    fi
    
    if [ ! -f "$step_dir/run.sh" ]; then
        echo "Error: Run script not found: $step_dir/run.sh"
        PIPELINE_STATUS+=("$step_name:no_script")
        FAILED_STEPS+=("$step_name")
        return 1
    fi
    
    # Execute step
    cd "$step_dir"
    ./run.sh > "$log_file" 2>&1
    local exit_code=$?
    cd - > /dev/null
    
    if [ $exit_code -eq 0 ]; then
        echo "[$(date)] Step completed successfully: $step_name"
        PIPELINE_STATUS+=("$step_name:success")
        return 0
    elif [ $exit_code -eq 2 ]; then
        echo "[$(date)] Step completed with warnings: $step_name"
        PIPELINE_STATUS+=("$step_name:partial")
        return 0
    else
        echo "[$(date)] Step failed: $step_name (exit code: $exit_code)"
        PIPELINE_STATUS+=("$step_name:failed")
        FAILED_STEPS+=("$step_name")
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --step STEP_NAME    Run only the specified step"
    echo "  --from STEP_NAME    Start from the specified step"
    echo "  --to STEP_NAME      Stop at the specified step"
    echo "  --test             Run tests for all steps instead of execution"
    echo "  --status           Show pipeline status"
    echo "  --help             Show this help message"
    echo ""
    echo "Available steps:"
    for step in "${STEP_ORDER[@]}"; do
        echo "  - $step"
    done
}

# Function to test all steps
test_pipeline() {
    echo "Running pipeline tests..."
    echo ""
    
    for step_name in "${STEP_ORDER[@]}"; do
        local step_dir="$STEPS_DIR/$step_name"
        echo "[$(date)] Testing step: $step_name"
        
        if [ -f "$step_dir/test.sh" ]; then
            cd "$step_dir"
            ./test.sh
            local exit_code=$?
            cd - > /dev/null
            
            if [ $exit_code -eq 0 ]; then
                echo "✓ $step_name tests passed"
            else
                echo "✗ $step_name tests failed"
                FAILED_STEPS+=("$step_name")
            fi
        else
            echo "- $step_name (no tests)"
        fi
        echo ""
    done
    
    if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
        echo "All pipeline tests passed!"
        return 0
    else
        echo "Failed tests: ${FAILED_STEPS[*]}"
        return 1
    fi
}

# Function to show pipeline status
show_status() {
    echo "Pipeline Status:"
    echo "================"
    
    for step_name in "${STEP_ORDER[@]}"; do
        local step_dir="$STEPS_DIR/$step_name"
        local status="not_run"
        
        # Check for output indicators
        if [ -d "$step_dir/outputs" ] && [ "$(ls -A "$step_dir/outputs" 2>/dev/null)" ]; then
            status="completed"
        elif [ -f "$LOG_DIR/${step_name}.log" ]; then
            status="attempted"
        fi
        
        printf "  %-25s %s\n" "$step_name:" "$status"
    done
    echo ""
}

# Parse command line arguments
RUN_SINGLE_STEP=""
START_FROM_STEP=""
STOP_AT_STEP=""
RUN_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --step)
            RUN_SINGLE_STEP="$2"
            shift 2
            ;;
        --from)
            START_FROM_STEP="$2"
            shift 2
            ;;
        --to)
            STOP_AT_STEP="$2"
            shift 2
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --status)
            show_status
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    test_pipeline
    exit $?
fi

# Determine which steps to run
STEPS_TO_RUN=()

if [ -n "$RUN_SINGLE_STEP" ]; then
    STEPS_TO_RUN=("$RUN_SINGLE_STEP")
else
    START_INDEX=0
    END_INDEX=$((${#STEP_ORDER[@]} - 1))
    
    if [ -n "$START_FROM_STEP" ]; then
        for i in "${!STEP_ORDER[@]}"; do
            if [ "${STEP_ORDER[$i]}" = "$START_FROM_STEP" ]; then
                START_INDEX=$i
                break
            fi
        done
    fi
    
    if [ -n "$STOP_AT_STEP" ]; then
        for i in "${!STEP_ORDER[@]}"; do
            if [ "${STEP_ORDER[$i]}" = "$STOP_AT_STEP" ]; then
                END_INDEX=$i
                break
            fi
        done
    fi
    
    for ((i=START_INDEX; i<=END_INDEX; i++)); do
        STEPS_TO_RUN+=("${STEP_ORDER[$i]}")
    done
fi

# Execute pipeline steps
echo "Executing pipeline steps: ${STEPS_TO_RUN[*]}"
echo ""

for step_name in "${STEPS_TO_RUN[@]}"; do
    if ! run_step "$step_name"; then
        echo ""
        echo "Pipeline execution stopped due to failure in step: $step_name"
        echo "Check log file: $LOG_DIR/${step_name}.log"
        break
    fi
    echo ""
done

# Generate pipeline summary
echo "=========================================="
echo "Pipeline Execution Summary"
echo "=========================================="
echo "Start time: $PIPELINE_START_TIME"
echo "End time: $(date)"
echo ""

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo "✓ Pipeline completed successfully!"
    echo ""
    echo "Final outputs can be found in:"
    echo "  - steps/08_performance_analysis/outputs/"
    echo "  - steps/07_evaluation_reporting/outputs/" 
    echo "  - steps/05_rca_agent_execution/outputs/"
    exit 0
else
    echo "✗ Pipeline completed with failures"
    echo "Failed steps: ${FAILED_STEPS[*]}"
    echo ""
    echo "Check log files in: $LOG_DIR/"
    exit 1
fi