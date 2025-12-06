"""
Lambda-optimized API configuration
"""
import os
from pathlib import Path

# Check if running in Lambda
IS_LAMBDA = bool(os.environ.get('AWS_LAMBDA_FUNCTION_NAME'))

if IS_LAMBDA:
    # Lambda paths
    DATA_DIR = Path("/tmp/out_snow")
    LOG_DIR = Path("/tmp/logs")
    STATIC_DIR = Path("/var/task/static")
    GENERATED_DIR = Path("/tmp/generated_forecasts")
    
    # Ensure directories exist
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    
    # Set Playwright cache directory
    os.environ['PLAYWRIGHT_BROWSERS_PATH'] = '/opt/playwright'
else:
    # Local development paths
    DATA_DIR = Path("out_snow")
    LOG_DIR = Path("logs")
    STATIC_DIR = Path("static")
    GENERATED_DIR = Path("generated_forecasts")