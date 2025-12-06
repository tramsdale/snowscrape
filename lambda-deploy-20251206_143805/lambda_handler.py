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
    # Check if this is a scheduled event for scraping
    if 'scheduled' in event and event.get('scheduled') == True:
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