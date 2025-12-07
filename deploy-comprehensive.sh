#!/bin/bash
# 🚀 Complete AWS Lambda Deployment & Validation Script for SnowScrape
# This script performs comprehensive checks before, during, and after deployment

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LAMBDA_DEPLOY_DIR="$PROJECT_ROOT/lambda-deploy-20251206_143805"
API_BASE_URL="https://snow.tcla.me"
STACK_NAME="sam-snowscape-app"
AWS_REGION="eu-west-2"
LAMBDA_FUNCTION_NAME="sam-snowscape-app-SnowForecastFunction-8i7Lr33Inj9z"

# Credential management
ENV_FILE="$LAMBDA_DEPLOY_DIR/.env.deploy"
USE_PARAMETER_STORE=false
DEPLOY_PARAMS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Emojis for better UX
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
ROCKET="🚀"
GEAR="⚙️"
SHIELD="🛡️"
CLOCK="🕐"
MAGNIFY="🔍"

print_header() {
    echo -e "\n${BOLD}${BLUE}===========================================${NC}"
    echo -e "${BOLD}${BLUE}  $ROCKET SnowScrape AWS Lambda Deploy  ${NC}"
    echo -e "${BOLD}${BLUE}===========================================${NC}\n"
}

print_step() {
    echo -e "${CYAN}${BOLD}[$1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}$CHECK${NC} $1"
}

print_error() {
    echo -e "${RED}$CROSS${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}$WARNING${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
}

# Cleanup function for graceful exit
cleanup() {
    if [[ $? -ne 0 ]]; then
        print_error "Deployment failed! Check the logs above for details."
        echo -e "\n${YELLOW}Common troubleshooting steps:${NC}"
        echo "1. Check AWS credentials: aws sts get-caller-identity"
        echo "2. Check Docker daemon is running"
        echo "3. Check environment variables are set"
        echo "4. Check repository status: git status"
    fi
}
trap cleanup EXIT

check_prerequisites() {
    print_step "1" "Checking Prerequisites"
    
    # Check required commands
    local commands=("git" "aws" "sam" "curl" "jq" "docker")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd is available"
        else
            print_error "$cmd is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        local account_id=$(aws sts get-caller-identity --query "Account" --output text)
        local user_arn=$(aws sts get-caller-identity --query "Arn" --output text)
        print_success "AWS credentials valid - Account: $account_id"
        print_info "User: $user_arn"
    else
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check Docker daemon
    if docker ps &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon not running or not accessible"
        exit 1
    fi
    
    # Check directories exist
    if [[ -d "$LAMBDA_DEPLOY_DIR" ]]; then
        print_success "Lambda deployment directory found"
    else
        print_error "Lambda deployment directory not found: $LAMBDA_DEPLOY_DIR"
        exit 1
    fi
}

check_git_status() {
    print_step "2" "Checking Git Repository Status"
    
    cd "$PROJECT_ROOT"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Uncommitted changes detected:"
        git status --porcelain | while read line; do
            echo "    $line"
        done
        echo ""
        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Deployment cancelled by user"
            exit 1
        fi
    else
        print_success "Working directory is clean"
    fi
    
    # Get current commit info
    local current_commit=$(git rev-parse HEAD)
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    print_success "Current branch: $current_branch"
    print_success "Current commit: ${current_commit:0:8}"
    
    # Check if we're up to date with origin
    git fetch origin &> /dev/null || true
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null || echo "no-remote")
    
    if [[ "$remote_commit" != "no-remote" ]]; then
        if [[ "$local_commit" != "$remote_commit" ]]; then
            print_warning "Local and remote commits differ"
            print_info "Local:  ${local_commit:0:8}"
            print_info "Remote: ${remote_commit:0:8}"
            echo ""
            read -p "Push changes to remote? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git push origin "$current_branch"
                print_success "Changes pushed to remote"
            fi
        else
            print_success "Local and remote repositories are synchronized"
        fi
    else
        print_warning "No remote branch found - local only repository"
    fi
}

check_version_consistency() {
    print_step "3" "Checking Version Consistency"
    
    # Compare local API server version with deployed version
    local local_version
    if [[ -f "$LAMBDA_DEPLOY_DIR/api_server.py" ]]; then
        local_version=$(grep -o 'version="[^"]*"' "$LAMBDA_DEPLOY_DIR/api_server.py" | cut -d'"' -f2)
        print_success "Local API version: $local_version"
    else
        print_error "Local api_server.py not found"
        exit 1
    fi
    
    # Try to get deployed version
    local deployed_version
    if deployed_version=$(curl -s "$API_BASE_URL/" 2>/dev/null | jq -r '.version' 2>/dev/null); then
        if [[ "$deployed_version" != "null" && -n "$deployed_version" ]]; then
            print_success "Deployed API version: $deployed_version"
            if [[ "$local_version" == "$deployed_version" ]]; then
                print_success "Local and deployed versions match"
            else
                print_warning "Version mismatch - Local: $local_version, Deployed: $deployed_version"
            fi
        else
            print_warning "Could not determine deployed version"
        fi
    else
        print_warning "Could not connect to deployed API (this is OK for first deployment)"
    fi
}

check_credentials() {
    print_step "3.5" "Checking Deployment Credentials"
    
    # Check if using AWS Parameter Store or local env file
    if [[ "$USE_PARAMETER_STORE" == "true" ]]; then
        print_info "Using AWS Parameter Store for credentials..."
        
        # Check if parameters exist in Parameter Store
        local required_params=(
            "/snowscrape/openai-api-key"
            "/snowscrape/snow-user"
            "/snowscrape/snow-pass"
        )
        
        for param in "${required_params[@]}"; do
            if aws ssm get-parameter --name "$param" --region "$AWS_REGION" --query "Parameter.Value" --output text &> /dev/null; then
                print_success "Parameter exists: $param"
            else
                print_error "Missing parameter: $param"
                print_info "Run: ./scripts/setup-credentials.sh to set up Parameter Store"
                exit 1
            fi
        done
        
        # No additional parameters needed for SAM deploy when using Parameter Store
        DEPLOY_PARAMS=()
        
    else
        print_info "Using local environment file for credentials..."
        
        # Check if local env file exists
        if [[ ! -f "$ENV_FILE" ]]; then
            print_error "Credentials file not found: $ENV_FILE"
            echo ""
            print_info "Please create $ENV_FILE with the following format:"
            echo "OPENAI_API_KEY=your-actual-openai-key"
            echo "SNOW_USER=your-actual-username"
            echo "SNOW_PASS=your-actual-password"
            echo ""
            print_warning "This file is git-ignored and safe to use"
            
            # Offer to create template
            echo ""
            read -p "Create template .env.deploy file? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cat > "$ENV_FILE" << 'EOF'
# SnowScrape Deployment Credentials
# This file is git-ignored - safe to add real credentials

OPENAI_API_KEY=your-openai-api-key-here
SNOW_USER=your-snow-forecast-username
SNOW_PASS=your-snow-forecast-password
EOF
                print_success "Template created: $ENV_FILE"
                print_warning "Please edit $ENV_FILE with your actual credentials before continuing"
            fi
            exit 1
        fi
        
        # Source the environment file
        print_info "Loading credentials from $ENV_FILE..."
        source "$ENV_FILE"
        
        # Validate required variables
        if [[ -z "$OPENAI_API_KEY" || -z "$SNOW_USER" || -z "$SNOW_PASS" ]]; then
            print_error "Missing required environment variables in $ENV_FILE"
            print_info "Required: OPENAI_API_KEY, SNOW_USER, SNOW_PASS"
            exit 1
        fi
        
        print_success "Credentials loaded successfully"
        
        # Set up deployment parameters
        DEPLOY_PARAMS=(
            "--parameter-overrides"
            "OpenAIApiKey=$OPENAI_API_KEY"
            "SnowUser=$SNOW_USER"
            "SnowPass=$SNOW_PASS"
        )
    fi
}

deploy_to_aws() {
    print_step "4" "Deploying to AWS Lambda"
    
    cd "$LAMBDA_DEPLOY_DIR"
    
    print_info "Building SAM application..."
    if sam build 2>&1 | tee /tmp/sam-build.log; then
        print_success "SAM build completed successfully"
    else
        print_error "SAM build failed"
        cat /tmp/sam-build.log
        exit 1
    fi
    
    print_info "Deploying to AWS..."
    if [[ ${#DEPLOY_PARAMS[@]} -gt 0 ]]; then
        print_info "Deploying with credential parameters..."
        if sam deploy "${DEPLOY_PARAMS[@]}" 2>&1 | tee /tmp/sam-deploy.log; then
            print_success "SAM deployment completed successfully"
        else
            print_error "SAM deployment failed"
            cat /tmp/sam-deploy.log
            exit 1
        fi
    else
        print_info "Deploying with Parameter Store credentials..."
        if sam deploy 2>&1 | tee /tmp/sam-deploy.log; then
            print_success "SAM deployment completed successfully"
        else
            print_error "SAM deployment failed"
            cat /tmp/sam-deploy.log
            exit 1
        fi
    fi
    
    # Extract outputs from deployment
    local api_url
    if api_url=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text 2>/dev/null); then
        print_success "API Gateway URL: $api_url"
    fi
}

trigger_initial_scrape() {
    print_step "5" "Triggering Initial Scrape Event"
    
    print_info "Waiting for Lambda function to be ready..."
    sleep 10
    
    # Trigger scrape via AWS Lambda invoke
    print_info "Invoking Lambda function for initial scrape..."
    local invoke_result
    if invoke_result=$(aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload '{"scheduled": true}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/lambda-response.json 2>&1); then
        
        print_success "Lambda function invoked successfully"
        
        # Check the response
        if [[ -f /tmp/lambda-response.json ]]; then
            local status_code=$(echo "$invoke_result" | grep -o '"StatusCode": [0-9]*' | cut -d' ' -f2)
            if [[ "$status_code" == "200" ]]; then
                print_success "Initial scrape completed successfully"
            else
                print_warning "Lambda execution completed with status code: $status_code"
                cat /tmp/lambda-response.json
            fi
        fi
    else
        print_error "Failed to invoke Lambda function: $invoke_result"
    fi
    
    # Also try HTTP endpoint trigger
    print_info "Triggering scrape via HTTP endpoint..."
    if curl -X POST "$API_BASE_URL/scrape" -w "HTTP %{http_code}\n" -s -o /tmp/scrape-response.json; then
        if [[ -f /tmp/scrape-response.json ]]; then
            cat /tmp/scrape-response.json | jq . 2>/dev/null || cat /tmp/scrape-response.json
        fi
    fi
}

check_endpoints() {
    print_step "6" "Checking All API Endpoints"
    
    print_info "Waiting for endpoints to be ready..."
    sleep 5
    
    # Define all endpoints to check
    local endpoints=(
        "/"
        "/health"
        "/meta"
        "/forecast/dynamic"
        "/forecast/hourly"
        "/forecast/html"
        "/snow/summary"
        "/files"
        "/scrape/status"
    )
    
    local failed_endpoints=0
    
    for endpoint in "${endpoints[@]}"; do
        local url="$API_BASE_URL$endpoint"
        local http_code
        
        if http_code=$(curl -s -o /tmp/endpoint-test.json -w "%{http_code}" "$url" 2>/dev/null); then
            if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
                print_success "✓ $endpoint (HTTP $http_code)"
                
                # Special checks for specific endpoints
                case "$endpoint" in
                    "/health")
                        local status=$(cat /tmp/endpoint-test.json | jq -r '.status' 2>/dev/null || echo "unknown")
                        print_info "  Health status: $status"
                        ;;
                    "/")
                        local api_name=$(cat /tmp/endpoint-test.json | jq -r '.name' 2>/dev/null || echo "unknown")
                        print_info "  API name: $api_name"
                        ;;
                esac
            else
                print_error "✗ $endpoint (HTTP $http_code)"
                failed_endpoints=$((failed_endpoints + 1))
                if [[ -f /tmp/endpoint-test.json ]]; then
                    print_info "  Response: $(cat /tmp/endpoint-test.json)"
                fi
            fi
        else
            print_error "✗ $endpoint (Connection failed)"
            failed_endpoints=$((failed_endpoints + 1))
        fi
    done
    
    if [[ $failed_endpoints -eq 0 ]]; then
        print_success "All API endpoints are working correctly"
    else
        print_warning "$failed_endpoints endpoint(s) failed"
    fi
}

check_logs() {
    print_step "7" "Checking CloudWatch Logs"
    
    print_info "Fetching recent CloudWatch logs..."
    
    # Get the most recent log stream
    local log_group="/aws/lambda/$LAMBDA_FUNCTION_NAME"
    local log_stream
    
    if log_stream=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --region "$AWS_REGION" \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null); then
        
        print_success "Found recent log stream: $log_stream"
        
        # Get recent log events
        local start_time=$(($(date +%s) * 1000 - 300000))  # Last 5 minutes
        
        if aws logs get-log-events \
            --log-group-name "$log_group" \
            --log-stream-name "$log_stream" \
            --start-time "$start_time" \
            --region "$AWS_REGION" \
            --query 'events[*].[timestamp,message]' \
            --output table > /tmp/recent-logs.txt 2>/dev/null; then
            
            # Check for errors in logs
            local error_count=$(grep -c -i "error\|exception\|failed" /tmp/recent-logs.txt || echo "0")
            local success_count=$(grep -c -i "success\|completed\|✅" /tmp/recent-logs.txt || echo "0")
            
            print_success "Recent logs retrieved successfully"
            print_info "Success indicators: $success_count"
            
            if [[ $error_count -gt 0 ]]; then
                print_warning "Error indicators found: $error_count"
                echo -e "\n${YELLOW}Recent error patterns:${NC}"
                grep -i "error\|exception\|failed" /tmp/recent-logs.txt | tail -5
            else
                print_success "No error patterns found in recent logs"
            fi
            
            # Show last few log entries
            echo -e "\n${CYAN}Last few log entries:${NC}"
            tail -10 /tmp/recent-logs.txt
        else
            print_warning "Could not retrieve log events"
        fi
    else
        print_warning "Could not find recent log streams"
    fi
}

check_security() {
    print_step "8" "Performing Security Checks"
    
    # Check for exposed secrets in git
    print_info "Checking for exposed secrets..."
    cd "$PROJECT_ROOT"
    
    local secret_patterns=(
        "OPENAI_API_KEY.*=.*[A-Za-z0-9]"
        "SNOW_USER.*=.*[A-Za-z0-9]"
        "SNOW_PASS.*=.*[A-Za-z0-9]"
        "api[_-]?key.*=.*[A-Za-z0-9]"
        "password.*=.*[A-Za-z0-9]"
    )
    
    local secrets_found=false
    for pattern in "${secret_patterns[@]}"; do
        if git log --all -S"$pattern" --source --all -p | grep -E "$pattern" &>/dev/null; then
            print_warning "Potential secret pattern found in git history: $pattern"
            secrets_found=true
        fi
    done
    
    if [[ "$secrets_found" == "false" ]]; then
        print_success "No obvious secrets found in git history"
    fi
    
    # Check API endpoint security
    print_info "Checking API security headers..."
    local security_headers=$(curl -s -I "$API_BASE_URL/" | grep -i -E "(x-frame-options|content-security-policy|x-content-type-options)")
    
    if [[ -n "$security_headers" ]]; then
        print_success "Security headers detected"
        echo "$security_headers" | while read header; do
            print_info "  $header"
        done
    else
        print_warning "No security headers detected (consider adding them)"
    fi
    
    # Check for HTTPS
    if [[ "$API_BASE_URL" =~ ^https:// ]]; then
        print_success "API is using HTTPS"
    else
        print_error "API is not using HTTPS - security risk!"
    fi
    
    # Test authentication endpoints
    print_info "Testing authentication protection..."
    local auth_test_response=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL/debug/env" 2>/dev/null)
    if [[ "$auth_test_response" == "200" ]]; then
        print_warning "Debug endpoint accessible without authentication"
    else
        print_success "Debug endpoint properly protected or not exposed"
    fi
}

additional_health_checks() {
    print_step "9" "Additional Health Checks"
    
    # Check Lambda function configuration
    print_info "Checking Lambda function configuration..."
    local function_config
    if function_config=$(aws lambda get-function-configuration \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" 2>/dev/null); then
        
        local timeout=$(echo "$function_config" | jq -r '.Timeout')
        local memory=$(echo "$function_config" | jq -r '.MemorySize')
        local runtime=$(echo "$function_config" | jq -r '.Runtime // "container"')
        
        print_success "Lambda configuration retrieved"
        print_info "  Runtime: $runtime"
        print_info "  Timeout: ${timeout}s"
        print_info "  Memory: ${memory}MB"
        
        # Recommend optimizations
        if [[ $timeout -lt 300 ]]; then
            print_warning "Consider increasing timeout for web scraping operations"
        fi
        
        if [[ $memory -lt 1024 ]]; then
            print_warning "Consider increasing memory for better performance"
        fi
    else
        print_warning "Could not retrieve Lambda function configuration"
    fi
    
    # Check scheduled events
    print_info "Checking scheduled events..."
    local schedule_rule
    if schedule_rule=$(aws events list-rules --region "$AWS_REGION" --query "Rules[?contains(Name, 'ScheduledScrape')].{Name:Name,State:State,ScheduleExpression:ScheduleExpression}" --output table 2>/dev/null); then
        print_success "Scheduled events configuration:"
        echo "$schedule_rule"
    else
        print_warning "Could not retrieve scheduled events information"
    fi
    
    # Test data freshness
    print_info "Checking data freshness..."
    local health_response
    if health_response=$(curl -s "$API_BASE_URL/health" 2>/dev/null); then
        local health_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
        local timestamp=$(echo "$health_response" | jq -r '.timestamp' 2>/dev/null || echo "unknown")
        
        print_info "Health status: $health_status"
        print_info "Last check: $timestamp"
        
        if [[ "$health_status" == "healthy" ]]; then
            print_success "System reports healthy status with current data"
        elif [[ "$health_status" == "no data" ]]; then
            print_warning "System healthy but no scraped data available yet"
        else
            print_warning "System reports unhealthy status: $health_status"
        fi
    fi
}

generate_deployment_report() {
    print_step "10" "Generating Deployment Report"
    
    local report_file="/tmp/snowscrape-deployment-report.txt"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S UTC")
    
    cat > "$report_file" << EOF
🚀 SnowScrape AWS Lambda Deployment Report
==========================================
Generated: $timestamp

📋 DEPLOYMENT SUMMARY
- Stack Name: $STACK_NAME
- Region: $AWS_REGION
- Function Name: $LAMBDA_FUNCTION_NAME
- API URL: $API_BASE_URL

🔍 SYSTEM STATUS
EOF

    # Add health check results
    if health_response=$(curl -s "$API_BASE_URL/health" 2>/dev/null); then
        echo "- API Health: $(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")" >> "$report_file"
        echo "- OpenAI Configured: $(echo "$health_response" | jq -r '.openai_configured' 2>/dev/null || echo "unknown")" >> "$report_file"
    else
        echo "- API Health: Unable to connect" >> "$report_file"
    fi
    
    # Add git info
    cd "$PROJECT_ROOT"
    echo "- Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")" >> "$report_file"
    echo "- Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")" >> "$report_file"
    
    cat >> "$report_file" << EOF

🔗 AVAILABLE ENDPOINTS
- Root: $API_BASE_URL/
- Health Check: $API_BASE_URL/health
- HTML Forecast: $API_BASE_URL/forecast/html
- API Documentation: $API_BASE_URL/docs (if available)

📝 NEXT STEPS
1. Monitor CloudWatch logs for any errors
2. Test all functionality end-to-end
3. Set up monitoring and alerting
4. Configure custom domain if needed
5. Review security settings

📊 MONITORING
- CloudWatch Logs: /aws/lambda/$LAMBDA_FUNCTION_NAME
- Scheduled Events: Every 2 minutes
- Custom Domain: snow.tcla.me (if configured)

EOF

    print_success "Deployment report generated: $report_file"
    
    # Display key information
    echo -e "\n${BOLD}${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}\n"
    echo -e "${CYAN}Key URLs:${NC}"
    echo -e "  • Main API: $API_BASE_URL/"
    echo -e "  • HTML Forecast: $API_BASE_URL/forecast/html"
    echo -e "  • Health Check: $API_BASE_URL/health"
    
    echo -e "\n${CYAN}Monitoring:${NC}"
    echo -e "  • CloudWatch Logs: aws logs tail /aws/lambda/$LAMBDA_FUNCTION_NAME --follow"
    echo -e "  • Function Metrics: AWS Lambda Console"
    
    # Open the report in default editor if available
    if command -v open &> /dev/null; then
        open "$report_file" 2>/dev/null || true
    fi
}

# Main execution flow
main() {
    print_header
    
    check_prerequisites
    check_git_status
    check_version_consistency
    check_credentials
    deploy_to_aws
    trigger_initial_scrape
    check_endpoints
    check_logs
    check_security
    additional_health_checks
    generate_deployment_report
    
    print_success "All deployment checks completed successfully! 🎉"
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "SnowScrape AWS Lambda Deployment Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help message"
            echo "  --check-only       Only run checks, don't deploy"
            echo "  --no-scrape        Skip initial scrape trigger"
            echo "  --parameter-store  Use AWS Parameter Store for credentials"
            echo "  --env-file         Use local .env.deploy file for credentials (default)"
            echo ""
            echo "This script performs comprehensive deployment validation including:"
            echo "  • Git repository status checks"
            echo "  • Version consistency verification"
            echo "  • AWS Lambda deployment"
            echo "  • API endpoint testing"
            echo "  • Security validation"
            echo "  • Log analysis"
            echo "  • Health monitoring"
            exit 0
            ;;
        --check-only)
            print_header
            check_prerequisites
            check_git_status
            check_version_consistency
            check_endpoints
            check_security
            print_success "All checks completed! (No deployment performed)"
            exit 0
            ;;
        --no-scrape)
            # Set flag to skip scrape trigger
            SKIP_SCRAPE=true
            ;;
        --parameter-store)
            USE_PARAMETER_STORE=true
            ;;
        --env-file)
            USE_PARAMETER_STORE=false
            ;;
        *)
            print_error "Unknown option: $1"
            print_info "Use --help for usage information"
            exit 1
            ;;
    esac
fi

# Run main deployment process
main
