#!/usr/bin/env python3
"""
Simple Lambda handler without Playwright for testing
"""

import os
import json
from pathlib import Path
from fastapi import FastAPI
from mangum import Mangum
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create a simplified FastAPI app for testing
app = FastAPI(
    title="Snow Forecast API (Lambda Test)",
    description="Simplified API for AWS Lambda testing",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {
        "message": "Snow Forecast API running on AWS Lambda!",
        "environment": "AWS Lambda",
        "openai_configured": bool(os.environ.get('OPENAI_API_KEY')),
        "python_path": os.environ.get('PYTHONPATH', 'Not set')
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "environment_variables": {
            "OPENAI_API_KEY": "***" if os.environ.get('OPENAI_API_KEY') else "Not set",
            "AWS_LAMBDA_FUNCTION_NAME": os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'Not set'),
            "PLAYWRIGHT_BROWSERS_PATH": os.environ.get('PLAYWRIGHT_BROWSERS_PATH', 'Not set')
        }
    }

# Create the Lambda handler
handler = Mangum(app)

def lambda_handler(event, context):
    """
    AWS Lambda handler function
    """
    return handler(event, context)