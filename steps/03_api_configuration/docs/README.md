# Step 03: API Configuration Setup

## Overview
This step configures API keys and model settings for LLM providers (OpenAI, Anthropic) used in the OpenRCA pipeline. It validates configurations and detects model capabilities without making actual API calls.

## Purpose
- Configure LLM provider API credentials securely
- Validate API configuration format and structure
- Detect model capabilities and limitations
- Create validated configuration for pipeline consumption

## Inputs
- `inputs/api_config_template.yaml`: Complete configuration template
- `inputs/config_validator.py`: Comprehensive validation script

## Outputs
- `outputs/api_config.yaml`: Validated API configuration
- `outputs/config_validation.json`: Detailed validation results  
- `outputs/model_capabilities.json`: Detected model capabilities and costs

## Dependencies
- Step 01: Environment Setup (requires Python packages)

## Requirements
- API keys for chosen LLM provider (OpenAI or Anthropic)
- Internet connection for API validation (optional)
- Environment variables or direct configuration

## Supported Providers

### OpenAI
- **Models**: gpt-4o-2024-05-13, gpt-4-turbo, gpt-4, gpt-3.5-turbo
- **API Key Format**: sk-[48+ characters]
- **Environment Variable**: OPENAI_API_KEY

### Anthropic  
- **Models**: claude-3-sonnet-20240229, claude-3-haiku-20240307, claude-3-opus-20240229
- **API Key Format**: sk-ant-[95+ characters]
- **Environment Variable**: ANTHROPIC_API_KEY

## Configuration Options

### Method 1: Environment Variables (Recommended)
```bash
export OPENAI_API_KEY="your-openai-key"
export ANTHROPIC_API_KEY="your-anthropic-key"
./run.sh
```

### Method 2: Direct Configuration
1. Edit `outputs/api_config.yaml` after first run
2. Update SOURCE, MODEL, and API_KEY fields
3. Re-run validation

## Execution
```bash
./run.sh
```

## Testing
```bash
./test.sh
```

## Configuration Template
The template includes:
- **Provider Configuration**: Primary and alternative providers
- **Model Parameters**: Temperature, max tokens, timeout settings
- **Rate Limiting**: Requests and token limits
- **Security Settings**: Logging and privacy controls
- **Cost Tracking**: Optional cost monitoring

## Key Features
- **Security First**: API keys handled securely, never logged
- **Format Validation**: Validates API key formats without API calls
- **Capability Detection**: Automatically detects model capabilities
- **Flexible Configuration**: Supports environment variables or direct keys
- **Cost Estimation**: Provides cost estimates for different models

## Model Capabilities
Automatically detected for each model:
- Context length limits
- Function calling support
- Vision capabilities (for supported models)
- Estimated costs per 1K tokens

## Security Considerations
- API keys are never logged or exposed in outputs
- Environment variable substitution for secure key management
- HTTPS validation for custom API endpoints
- Response logging disabled by default

## Common Issues
1. **Invalid API Key Format**: Check key format matches provider requirements
2. **Environment Variables**: Ensure variables are set in current shell
3. **Model Compatibility**: Verify model name matches provider's offerings
4. **Rate Limits**: Adjust rate limiting based on your API plan

## Cost Management
- Configurable cost thresholds and alerts
- Per-run cost limits
- Token usage tracking
- Model-specific pricing estimates

## Configuration Files
- **Template**: Complete configuration template with all options
- **Validated**: Production-ready configuration with substituted values
- **Validation Results**: Detailed validation report with errors/warnings
- **Capabilities**: Model-specific capabilities and limitations