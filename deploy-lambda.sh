#!/bin/bash

# AWS Lambda deployment script for Snow Forecast API
set -e

echo "🚀 Deploying Snow Forecast API to AWS Lambda..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    echo "   pip install awscli"
    exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI is not installed. Please install it first."
    echo "   pip install aws-sam-cli"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get OpenAI API key from environment or prompt
if [ -z "$OPENAI_API_KEY" ]; then
    if [ -f ".env" ]; then
        echo "📝 Loading environment from .env file..."
        source .env
    fi
    
    if [ -z "$OPENAI_API_KEY" ]; then
        read -s -p "🔑 Enter your OpenAI API key: " OPENAI_API_KEY
        echo
    fi
fi

# Create deployment directory
DEPLOY_DIR="lambda-deploy"
rm -rf $DEPLOY_DIR
mkdir -p $DEPLOY_DIR

echo "📦 Preparing deployment package..."

# Copy source files
cp -r src/ $DEPLOY_DIR/
cp lambda_handler.py $DEPLOY_DIR/
cp requirements.txt $DEPLOY_DIR/
cp template.yaml $DEPLOY_DIR/
cp -r out_snow/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No out_snow directory found - will be created on first run"
cp -r generated_forecasts/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No generated_forecasts directory found - will be created on first run"

# Create Playwright layer directory structure
echo "🎭 Preparing Playwright layer..."
mkdir -p $DEPLOY_DIR/layers/playwright/python/lib/python3.11/site-packages

# Note: Playwright browsers need to be built in a Lambda-compatible environment
echo "⚠️  NOTE: Playwright browsers must be built in a Lambda-compatible environment."
echo "   You may need to use AWS CodeBuild or a Lambda-compatible Docker container."
echo "   For now, we'll deploy without the browser layer and install at runtime."

cd $DEPLOY_DIR

# Build and deploy with SAM
echo "🏗️  Building with SAM..."
sam build

echo "🚀 Deploying to AWS Lambda..."
sam deploy --guided --parameter-overrides ParameterKey=OpenAIApiKey,ParameterValue="$OPENAI_API_KEY"

echo "✅ Deployment complete!"
echo "📄 Your API is now available at the URL shown above."
echo "🔧 You may need to increase timeout settings if scraping takes longer than expected."