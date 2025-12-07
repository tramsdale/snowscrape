#!/usr/bin/env python3
"""
Test script for AWS Lambda deployed Snow Forecast API
"""

import requests
import json
import sys
from typing import Optional

def test_api(base_url: str) -> None:
    """Test the deployed API endpoints"""
    print(f"🧪 Testing Snow Forecast API at: {base_url}")
    print("=" * 50)
    
    # Test root endpoint
    print("\n1️⃣ Testing root endpoint...")
    try:
        response = requests.get(base_url, timeout=10)
        response.raise_for_status()
        data = response.json()
        print(f"✅ Root endpoint: {response.status_code}")
        print(f"   Message: {data.get('message', 'N/A')}")
        if 'environment' in data:
            print(f"   Environment: {data['environment']}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Root endpoint failed: {e}")
        return
    
    # Test health endpoint
    print("\n2️⃣ Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}health", timeout=10)
        response.raise_for_status()
        data = response.json()
        print(f"✅ Health endpoint: {response.status_code}")
        print(f"   Status: {data.get('status', 'N/A')}")
        
        # Check environment variables
        env_vars = data.get('environment_variables', {})
        openai_key = env_vars.get('OPENAI_API_KEY', 'Not set')
        print(f"   OpenAI API Key: {'✅ Configured' if openai_key != 'Not set' else '❌ Not configured'}")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Health endpoint failed: {e}")
    
    # Test forecast endpoints if this is a full deployment
    print("\n3️⃣ Testing forecast endpoints...")
    
    # Try to access forecast/html
    try:
        response = requests.get(f"{base_url}forecast/html", timeout=30)
        if response.status_code == 200:
            print("✅ HTML forecast endpoint available")
            content_length = len(response.content)
            print(f"   Response size: {content_length} bytes")
        elif response.status_code == 404:
            print("ℹ️  HTML forecast endpoint not available (Simple deployment)")
        else:
            print(f"⚠️  HTML forecast endpoint returned: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"❌ HTML forecast endpoint failed: {e}")
    
    # Try to access forecast/generate
    try:
        response = requests.post(f"{base_url}forecast/generate", 
                               json={"format": "html"}, 
                               timeout=60)  # Longer timeout for generation
        if response.status_code == 200:
            print("✅ Generate forecast endpoint available")
            data = response.json()
            if 'forecast' in data:
                print("   Forecast generation successful")
        elif response.status_code == 404:
            print("ℹ️  Generate forecast endpoint not available (Simple deployment)")
        else:
            print(f"⚠️  Generate forecast endpoint returned: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Generate forecast endpoint failed: {e}")
    
    print("\n🎯 Test Summary:")
    print("   - Basic API functionality tested")
    print("   - Environment configuration checked")
    print("   - Forecast endpoints validated (if available)")
    print("\n💡 Tip: Check CloudWatch logs for detailed error information")

def main():
    if len(sys.argv) != 2:
        print("Usage: python test_lambda_api.py <API_GATEWAY_URL>")
        print("Example: python test_lambda_api.py https://abc123.execute-api.us-east-1.amazonaws.com/Prod/")
        sys.exit(1)
    
    api_url = sys.argv[1]
    if not api_url.endswith('/'):
        api_url += '/'
    
    test_api(api_url)

if __name__ == "__main__":
    main()