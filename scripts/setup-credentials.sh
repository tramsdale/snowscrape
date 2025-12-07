#!/bin/bash
# Setup AWS Parameter Store credentials for SnowScrape
# This script should be run once to set up credentials securely

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔐 SnowScrape Credentials Setup${NC}"
echo "This script will securely store your credentials in AWS Parameter Store"
echo ""

# Check AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

AWS_REGION="eu-west-2"

echo -e "${YELLOW}Setting up credentials for region: $AWS_REGION${NC}"
echo ""

# Function to create secure parameter
create_secure_parameter() {
    local param_name="$1"
    local param_description="$2"
    local param_value="$3"
    
    echo "Creating parameter: $param_name"
    aws ssm put-parameter \
        --name "$param_name" \
        --description "$param_description" \
        --value "$param_value" \
        --type "SecureString" \
        --region "$AWS_REGION" \
        --overwrite 2>/dev/null || {
        echo -e "${RED}❌ Failed to create parameter: $param_name${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ Parameter created: $param_name${NC}"
}

# Get credentials from user (hidden input for passwords)
echo "Please provide your credentials:"
echo ""

read -p "OpenAI API Key: " -s OPENAI_KEY
echo ""
read -p "Snow Forecast Username: " SNOW_USER
read -p "Snow Forecast Password: " -s SNOW_PASS
echo ""
echo ""

# Validate inputs
if [[ -z "$OPENAI_KEY" || -z "$SNOW_USER" || -z "$SNOW_PASS" ]]; then
    echo -e "${RED}❌ All credentials are required${NC}"
    exit 1
fi

# Create parameters
echo "Creating AWS Parameter Store entries..."
echo ""

create_secure_parameter \
    "/snowscrape/openai-api-key" \
    "OpenAI API Key for SnowScrape ski forecast generation" \
    "$OPENAI_KEY"

create_secure_parameter \
    "/snowscrape/snow-user" \
    "Snow Forecast website username for SnowScrape scraping" \
    "$SNOW_USER"

create_secure_parameter \
    "/snowscrape/snow-pass" \
    "Snow Forecast website password for SnowScrape scraping" \
    "$SNOW_PASS"

echo ""
echo -e "${GREEN}🎉 All credentials successfully stored in AWS Parameter Store!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Your credentials are now securely stored in AWS Parameter Store"
echo "2. The Lambda function will automatically retrieve them during deployment"
echo "3. Run 'sam build && sam deploy' to deploy with the new configuration"
echo ""
echo -e "${YELLOW}To update credentials later:${NC}"
echo "- Re-run this script to overwrite existing parameters"
echo "- Or use AWS Console: Systems Manager > Parameter Store"
echo ""
echo -e "${YELLOW}Security notes:${NC}"
echo "- Credentials are encrypted at rest in AWS"
echo "- Only your Lambda function can access these parameters"
echo "- No credentials are stored in your Git repository"
echo ""

# Test parameter retrieval
echo -e "${YELLOW}Testing parameter retrieval...${NC}"
if aws ssm get-parameter --name "/snowscrape/snow-user" --region "$AWS_REGION" --query "Parameter.Value" --output text &> /dev/null; then
    echo -e "${GREEN}✅ Parameters can be retrieved successfully${NC}"
else
    echo -e "${RED}❌ Warning: Could not test parameter retrieval${NC}"
fi