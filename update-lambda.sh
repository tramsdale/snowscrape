#!/bin/bash

# Update existing Lambda function with fixed code
set -e

FUNCTION_NAME="sam-snowscape-app-SnowForecastFunction-8i7Lr33Inj9z"
STACK_NAME="sam-snowscape-app"

echo "🔄 Updating existing Lambda function: $FUNCTION_NAME"
echo "=================================================="

# Use SAM to build and update just the function
echo "🏗️  Building updated function..."
sam build --use-container

echo "🚀 Updating Lambda function..."
sam deploy --stack-name $STACK_NAME --no-confirm-changeset --resolve-s3 --capabilities CAPABILITY_IAM

echo "✅ Lambda function updated!"
echo ""
echo "🧪 Test the updated function:"
echo "   curl -H 'Host: snow.tcla.me' https://d2t7bhy0gcfwcx.cloudfront.net/forecast/generate"