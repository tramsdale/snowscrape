#!/usr/bin/env python3
"""
Test OpenAI API key loading in the same way as api_server.py
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Replicate the same logic as api_server.py
print("Testing API server environment loading logic...")

# Load environment variables from multiple possible locations
load_dotenv()  # Try default locations first

# Also try to load from project directory explicitly
project_dir = Path(__file__).parent.parent
env_file = project_dir / ".env"
if env_file.exists():
    print(f"Loading from: {env_file}")
    load_dotenv(env_file)

# Manual fallback for cases where dotenv doesn't work
if not os.getenv('OPENAI_API_KEY') and env_file.exists():
    print("Using manual fallback parsing...")
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes if present
                value = value.strip('\'"')
                os.environ[key] = value
                print(f"Manually set: {key}")

# Check final result
api_key = os.getenv('OPENAI_API_KEY')
print(f"Final result: {'✅ SUCCESS' if api_key else '❌ FAILED'}")
if api_key:
    print(f"Key preview: {api_key[:10]}...{api_key[-10:] if len(api_key) > 20 else api_key[10:]}")