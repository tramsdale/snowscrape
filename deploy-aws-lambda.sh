#!/bin/bash

# AWS Lambda deployment script for Snow Forecast API
set -e

echo "🚀 Snow Forecast API - AWS Lambda Deployment"
echo "============================================="
echo
echo "Choose deployment type:"
echo "1) Simple (API only, no web scraping) - Quick test deployment"
echo "2) Full with ZIP (Complete with Playwright) - May have browser issues"
echo "3) Full with Docker (Complete with Playwright) - Recommended for production"
echo

read -p "Enter your choice (1, 2, or 3): " DEPLOYMENT_TYPE

case $DEPLOYMENT_TYPE in
    1)
        echo "📦 Deploying Simple API (no Playwright)..."
        HANDLER="lambda_handler_simple.lambda_handler"
        TEMPLATE="template-simple.yaml"
        REQUIREMENTS="requirements-simple.txt"
        DEPLOYMENT_METHOD="zip"
        ;;
    2)
        echo "📦 Deploying Full API with ZIP (with Playwright)..."
        HANDLER="lambda_handler.lambda_handler"
        TEMPLATE="template.yaml"
        REQUIREMENTS="requirements.txt"
        DEPLOYMENT_METHOD="zip"
        ;;
    3)
        echo "📦 Deploying Full API with Docker (with Playwright)..."
        HANDLER="lambda_handler_docker.lambda_handler"
        TEMPLATE="template-docker.yaml"
        REQUIREMENTS="requirements-lambda.txt"
        DEPLOYMENT_METHOD="docker"
        ;;
    *)
        echo "❌ Invalid choice. Please run again and select 1, 2, or 3."
        exit 1
        ;;
esac

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first:"
    echo "   uv tool install awscli"
    echo "   brew install awscli  # on macOS" 
    echo "   pip install awscli   # fallback"
    exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI is not installed. Please install it first:"
    echo "   uv tool install aws-sam-cli"
    echo "   brew install aws-sam-cli  # on macOS"
    echo "   pip install aws-sam-cli   # fallback"
    exit 1
fi

# Check if uv is installed (recommended for faster builds)
if ! command -v uv &> /dev/null; then
    echo "⚠️  uv is not installed. Installing for faster dependency management..."
    curl -LsSf https://astral.sh/uv/install.sh | sh || {
        echo "❌ Failed to install uv. Falling back to pip."
        USE_UV=false
    }
else
    USE_UV=true
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run:"
    echo "   aws configure"
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo

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
DEPLOY_DIR="lambda-deploy-$(date +%Y%m%d_%H%M%S)"
echo "📁 Creating deployment directory: $DEPLOY_DIR"
mkdir -p $DEPLOY_DIR

echo "📦 Preparing deployment package..."

# Copy source files
cp -r src/ $DEPLOY_DIR/
cp lambda_*.py $DEPLOY_DIR/
cp $REQUIREMENTS $DEPLOY_DIR/requirements.txt
cp $TEMPLATE $DEPLOY_DIR/template.yaml
cp lambda_config.py $DEPLOY_DIR/

# Copy additional files for full deployment
if [ "$DEPLOYMENT_TYPE" = "2" ] || [ "$DEPLOYMENT_TYPE" = "3" ]; then
    cp api_server.py $DEPLOY_DIR/
fi

# Copy Docker-specific files
if [ "$DEPLOYMENT_METHOD" = "docker" ]; then
    cp Dockerfile $DEPLOY_DIR/
    cp lambda_handler_docker.py $DEPLOY_DIR/
    # Docker needs all files in build context
    cp -r out_snow/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No out_snow directory found - will be created on first run"
    cp -r generated_forecasts/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No generated_forecasts directory found - will be created on first run"
fi

# Copy data directories if they exist
cp -r out_snow/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No out_snow directory - will be created at runtime"
cp -r generated_forecasts/ $DEPLOY_DIR/ 2>/dev/null || echo "⚠️  No generated_forecasts directory - will be created at runtime"

cd $DEPLOY_DIR

echo "🏗️  Building with SAM..."
sam build

echo "🚀 Deploying to AWS Lambda..."

# Use guided deployment for first time, or provide parameters directly
if [ ! -f "samconfig.toml" ]; then
    echo "📋 First deployment - using guided setup..."
    sam deploy \
        --guided \
        --parameter-overrides "ParameterKey=OpenAIApiKey,ParameterValue=$OPENAI_API_KEY"
else
    echo "📋 Using existing configuration..."
    sam deploy \
        --parameter-overrides "ParameterKey=OpenAIApiKey,ParameterValue=$OPENAI_API_KEY"
fi

echo
echo "✅ Deployment complete!"
echo
echo "📄 Your API endpoints:"
API_URL=$(sam list stack-outputs --output table | grep "ApiUrl" | awk '{print $4}' || echo "Check AWS Console for API URL")
echo "   Root: $API_URL"
echo "   Health: ${API_URL}health"

if [ "$DEPLOYMENT_TYPE" = "2" ] || [ "$DEPLOYMENT_TYPE" = "3" ]; then
    echo "   Forecast: ${API_URL}forecast/html"
    echo "   Generate: ${API_URL}forecast/generate"
fi

echo
echo "🔧 Notes:"
echo "   - Check CloudWatch logs if you encounter issues"
echo "   - Lambda timeout is set appropriately for your deployment type"
if [ "$DEPLOYMENT_TYPE" = "2" ]; then
    echo "   - ZIP deployment may have browser compatibility issues"
    echo "   - Consider using Docker deployment (option 3) for better Playwright support"
elif [ "$DEPLOYMENT_TYPE" = "3" ]; then
    echo "   - Docker deployment provides full Playwright browser support"
    echo "   - Initial deployment may take longer due to container image building"
fi

echo
echo "🗑️  Cleanup: You can delete the deployment directory when done:"
echo "   rm -rf $PWD"

cd ..
echo "📁 Deployment files saved in: $DEPLOY_DIR"