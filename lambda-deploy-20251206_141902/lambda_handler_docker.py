#!/usr/bin/env python3
"""
AWS Lambda handler for Snow Forecast API (Docker version)
"""

import os
import json
from pathlib import Path
from fastapi import FastAPI
from mangum import Mangum
from dotenv import load_dotenv

# Set up paths for Lambda environment
os.environ['PLAYWRIGHT_BROWSERS_PATH'] = '/tmp'
os.environ['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = '1'

# Load environment variables
load_dotenv()

# Import after environment setup
# For Docker deployment, we'll import the full API but handle Playwright gracefully
try:
    from api_server import app
    FULL_API_AVAILABLE = True
except Exception as e:
    print(f"Warning: Full API not available: {e}")
    # Fallback to simple API
    from lambda_handler_simple import app
    FULL_API_AVAILABLE = False

# Create the Lambda handler
handler = Mangum(app)

def lambda_handler(event, context):
    """
    AWS Lambda handler function
    """
    return handler(event, context)