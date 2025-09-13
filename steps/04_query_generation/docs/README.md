# Step 04: Query Generation and Task Specification

## Overview
This step generates queries and task specifications from ground truth data for OpenRCA evaluation. It uses LLMs to create realistic DevOps failure diagnosis scenarios based on historical failure records.

## Purpose
- Generate realistic failure diagnosis queries from ground truth data
- Create balanced distribution across task types and difficulty levels
- Handle multi-failure scenarios within time windows
- Produce evaluation-ready query datasets

## Inputs
- `inputs/task_specification.json`: Task templates and scoring criteria
- `inputs/prompt_templates.py`: LLM prompt templates for query generation
- `inputs/query_generator.py`: Main query generation script

## Outputs
- `outputs/queries/`: Generated query CSV files for each dataset
- `outputs/generation_report.json`: Detailed generation statistics and results
- `outputs/task_distribution.json`: Analysis of task type distribution
- `outputs/query_schema.json`: Complete schema documentation

## Dependencies
- Step 02: Dataset Preparation (requires validated datasets)
- Step 03: API Configuration (requires configured LLM access)

## Requirements
- Configured LLM API access (OpenAI or Anthropic)
- 4GB+ memory for LLM processing
- Internet connection for API calls
- Validated telemetry datasets

## Task Types
The system generates 7 different task types with increasing difficulty:

### Easy Tasks (Single Element Prediction)
- **Task 1**: Time prediction only
- **Task 2**: Reason prediction only  
- **Task 3**: Component prediction only

### Medium Tasks (Two Element Prediction)
- **Task 4**: Time + Reason prediction
- **Task 5**: Time + Component prediction
- **Task 6**: Component + Reason prediction

### Hard Tasks (Full Prediction)
- **Task 7**: Time + Component + Reason prediction

## Multi-Failure Handling
The system automatically detects when multiple failures occur within the same 30-minute window and generates appropriate multi-failure queries with multiple scoring criteria.

## Execution
```bash
./run.sh
```

## Testing
```bash
./test.sh
```

## Query Generation Process
1. **Load Ground Truth**: Parse failure records from each dataset
2. **Detect Time Conflicts**: Identify multi-failure scenarios
3. **Select Task Type**: Randomly assign task types for balanced distribution
4. **Build Specifications**: Create input/output specifications for LLM
5. **Generate Instructions**: Use LLM to create realistic failure scenarios
6. **Validate Output**: Ensure proper format and completeness

## Generated Query Format
Each generated query file contains:
- **task_index**: Task type (task_1 through task_7)
- **instruction**: Natural language failure description
- **scoring_points**: Evaluation criteria for the response

## Key Features
- **Realistic Scenarios**: LLM-generated failure descriptions that mimic real issues
- **Balanced Distribution**: Even spread across task types and difficulty levels
- **Multi-Failure Support**: Handles complex scenarios with multiple root causes
- **Timezone Consistency**: All timestamps in UTC+8 (Asia/Shanghai)
- **Reproducible**: Fixed random seed ensures consistent generation

## Quality Assurance
- Format validation for all generated queries
- Content validation against task specifications
- Statistical analysis of task distribution
- Error tracking and retry mechanisms

## Customization
The system supports:
- Custom task specifications via JSON configuration
- Alternative LLM providers (OpenAI, Anthropic)
- Configurable generation parameters
- Dataset-specific specifications (e.g., system names)

## Output Statistics
Generated reports include:
- Total queries generated per dataset
- Task type distribution analysis
- Multi-failure query statistics
- Generation success/failure rates
- Error analysis and troubleshooting information

## Common Issues
1. **API Limits**: Monitor rate limits for LLM providers
2. **Generation Failures**: Some queries may fail - retry logic included
3. **Memory Usage**: Large datasets may require more memory
4. **Network Issues**: Ensure stable internet for API calls

## Schema Compliance
All generated queries follow the OpenRCA evaluation format and are compatible with the evaluation pipeline in subsequent steps.