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
    # Debug: Print event structure to understand CloudWatch events
    print(f"DEBUG: Event keys: {list(event.keys())}")
    print(f"DEBUG: Event source: {event.get('source', 'no source')}")
    print(f"DEBUG: Event detail-type: {event.get('detail-type', 'no detail-type')}")
    
    # Check if this is a CloudWatch scheduled event for scraping
    if 'scheduled' in event:
        print("🔄 Scheduled scraping triggered")
        try:
            # Import and run scraper directly
            from snowscrape.scraper import main as scrape_main
            scrape_main()
            print("✅ Scheduled scraping completed successfully")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Scheduled scraping completed successfully',
                    'timestamp': context.aws_request_id
                })
            }
        except Exception as e:
            print(f"❌ Scheduled scraping failed: {e}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Scheduled scraping failed: {str(e)}',
                    'timestamp': context.aws_request_id
                })
            }
    
    # Otherwise handle as regular API request
    return handler(event, context)