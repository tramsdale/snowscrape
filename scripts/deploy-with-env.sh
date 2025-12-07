#!/bin/bash
# Deploy with local environment file
# This script reads credentials from .env.deploy (git-ignored) and deploys

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="$(dirname "$SCRIPT_DIR")/lambda-deploy-20251206_143805"
ENV_FILE="$LAMBDA_DIR/.env.deploy"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 SnowScrape Deployment with Local Credentials${NC}"

# Check if credentials file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}❌ Credentials file not found: $ENV_FILE${NC}"
    echo ""
    echo "Please create $ENV_FILE with the following format:"
    echo ""
    echo "OPENAI_API_KEY=your-actual-openai-key"
    echo "SNOW_USER=your-actual-username"
    echo "SNOW_PASS=your-actual-password"
    echo ""
    echo -e "${YELLOW}Note: This file is git-ignored and safe to use${NC}"
    exit 1
fi

# Source the environment file
echo "Loading credentials from $ENV_FILE..."
source "$ENV_FILE"

# Validate required variables
if [[ -z "$OPENAI_API_KEY" || -z "$SNOW_USER" || -z "$SNOW_PASS" ]]; then
    echo -e "${RED}❌ Missing required environment variables in $ENV_FILE${NC}"
    echo "Required: OPENAI_API_KEY, SNOW_USER, SNOW_PASS"
    exit 1
fi

echo -e "${GREEN}✅ Credentials loaded successfully${NC}"

# Deploy with environment variables as parameters
cd "$LAMBDA_DIR"
echo "Building and deploying..."

sam build && sam deploy \
    --parameter-overrides \
        "OpenAIApiKey=$OPENAI_API_KEY" \
        "SnowUser=$SNOW_USER" \
        "SnowPass=$SNOW_PASS"

echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"