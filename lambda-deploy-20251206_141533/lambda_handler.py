#!/usr/bin/env python3
"""
AWS Lambda handler for Snow Forecast API
"""

import os
import json
from pathlib import Path
from fastapi import FastAPI
from mangum import Mangum
from dotenv import load_dotenv

# Set up paths for Lambda environment
os.environ['PLAYWRIGHT_BROWSERS_PATH'] = '/tmp'

# Load environment variables
load_dotenv()

# Import after environment setup
from api_server import app

# Create the Lambda handler
handler = Mangum(app)

def lambda_handler(event, context):
    """
    AWS Lambda handler function
    """
    return handler(event, context)