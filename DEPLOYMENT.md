# 🚀 Comprehensive AWS Lambda Deployment Script

## Overview

This script (`deploy-comprehensive.sh`) provides a complete deployment pipeline for the SnowScrape AWS Lambda application with comprehensive validation and monitoring.

## What It Does

### ✅ Pre-Deployment Checks
- **Prerequisites**: Verifies all required tools (git, aws, sam, curl, jq, docker)
- **AWS Credentials**: Validates AWS authentication and permissions
- **Git Status**: Checks for uncommitted changes and version synchronization
- **Version Consistency**: Compares local and deployed API versions
- **Docker**: Ensures Docker daemon is running

### 🚀 Deployment Process
- **SAM Build**: Compiles and packages the Lambda function
- **SAM Deploy**: Deploys to AWS with CloudFormation
- **Initial Scrape**: Triggers first data collection via AWS Lambda invoke
- **Health Verification**: Confirms deployment success

### 🔍 Post-Deployment Validation
- **API Endpoints**: Tests all 9+ API endpoints for correct responses
- **CloudWatch Logs**: Analyzes recent logs for errors and success patterns
- **Security Checks**: Scans for exposed secrets and security headers
- **Lambda Configuration**: Validates timeout, memory, and runtime settings
- **Scheduled Events**: Confirms cron job setup for automatic scraping

### 📊 Monitoring & Reporting
- **Comprehensive Report**: Generates detailed deployment summary
- **Health Dashboard**: Real-time status of all components
- **Next Steps**: Actionable recommendations for post-deployment

## Usage

### Basic Deployment
```bash
./deploy-comprehensive.sh
```

### Check Only (No Deployment)
```bash
./deploy-comprehensive.sh --check-only
```

### Skip Initial Scrape
```bash
./deploy-comprehensive.sh --no-scrape
```

### Help
```bash
./deploy-comprehensive.sh --help
```

## Prerequisites

### Required Tools
- **AWS CLI** (configured with valid credentials)
- **SAM CLI** (for serverless deployments)
- **Docker** (for container builds)
- **git** (for version control checks)
- **curl** (for API testing)
- **jq** (for JSON processing)

### AWS Permissions Required
- Lambda function management
- CloudFormation stack operations
- CloudWatch logs access
- EventBridge (for scheduled events)
- IAM role creation/management

## Configuration

The script automatically detects your configuration from:
- `lambda-deploy-20251206_143805/template.yaml` (SAM template)
- `lambda-deploy-20251206_143805/samconfig.toml` (deployment config)
- Current git repository status

### Key Settings
```bash
API_BASE_URL="https://snow.tcla.me"
STACK_NAME="sam-snowscape-app"  
AWS_REGION="eu-west-2"
LAMBDA_FUNCTION_NAME="sam-snowscape-app-SnowForecastFunction-8i7Lr33Inj9z"
```

## Output

### Success Output
```
==========================================
  🚀 SnowScrape AWS Lambda Deploy  
==========================================

✅ All prerequisites met
✅ Working directory is clean
✅ Local and deployed versions match
✅ SAM deployment completed successfully
✅ Initial scrape completed successfully
✅ All API endpoints are working correctly
✅ No error patterns found in recent logs
✅ No obvious secrets found in git history
✅ All deployment checks completed successfully! 🎉
```

### Deployment Report
The script generates a comprehensive report at `/tmp/snowscrape-deployment-report.txt` containing:
- Deployment summary with all URLs and identifiers
- System health status
- Available endpoints
- Monitoring instructions
- Next steps recommendations

## Troubleshooting

### Common Issues

**AWS Credentials**
```bash
# Check credentials
aws sts get-caller-identity

# Configure if needed
aws configure
```

**Docker Issues**
```bash
# Start Docker daemon
open -a Docker

# Check Docker status
docker ps
```

**Git Issues**
```bash
# Check repository status
git status

# Commit pending changes
git add . && git commit -m "Pre-deployment commit"
```

**SAM Build Failures**
```bash
# Check SAM installation
sam --version

# Clean build directory
rm -rf .aws-sam/
```

### Error Patterns to Look For

**In CloudWatch Logs:**
- `Login failed: Invalid username and password combination`
- `Error during scraping`
- `ImportError` or `ModuleNotFoundError`
- `TimeoutError` or connection issues

**In API Responses:**
- HTTP 5xx errors
- `{"detail": "Internal Server Error"}`
- Empty or malformed JSON responses

### Getting Help

**View Recent Logs:**
```bash
aws logs tail /aws/lambda/sam-snowscape-app-SnowForecastFunction-8i7Lr33Inj9z --follow
```

**Check Function Status:**
```bash
aws lambda get-function --function-name sam-snowscape-app-SnowForecastFunction-8i7Lr33Inj9z
```

**Test API Manually:**
```bash
curl -s https://snow.tcla.me/health | jq .
```

## Advanced Usage

### Customization
You can modify the script variables at the top to match your specific deployment:
- Change API base URL
- Modify AWS region
- Update stack names
- Add custom validation checks

### Integration
The script is designed to work with CI/CD pipelines:
- Returns proper exit codes (0 = success, 1 = failure)  
- Generates machine-readable output with `--check-only`
- Supports environment variable overrides
- Creates detailed logs for automation systems

### Monitoring Integration
The script outputs can be integrated with monitoring systems:
- Deployment reports can be sent to Slack/Teams
- Health checks can trigger alerts
- Log patterns can be forwarded to monitoring dashboards

## Security Features

The script includes several security validations:
- **Secret Detection**: Scans git history for exposed API keys
- **HTTPS Verification**: Ensures API uses secure connections  
- **Header Analysis**: Checks for security headers
- **Authentication Testing**: Validates protected endpoints
- **Permission Auditing**: Confirms minimal required AWS permissions

## Performance Optimization

The script provides recommendations for:
- Lambda memory allocation (suggests >1024MB for scraping)
- Timeout configuration (recommends 300s for web operations)
- Container optimization (suggests layer caching strategies)
- Cost optimization (monitors invocation patterns)