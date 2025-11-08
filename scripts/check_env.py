#!/usr/bin/env python3
"""
Environment Variable Diagnostic Script
Checks if OpenAI API key is properly loaded from various sources
"""

import os
import sys
from pathlib import Path

def check_env_loading():
    """Check OpenAI API key loading from various sources"""
    print("🔍 Environment Variable Diagnostic")
    print("=" * 50)
    
    # Check current environment
    current_key = os.getenv('OPENAI_API_KEY')
    print(f"Current OPENAI_API_KEY in environment: {'✅ SET' if current_key else '❌ NOT SET'}")
    if current_key:
        print(f"  Key preview: {current_key[:10]}...{current_key[-10:] if len(current_key) > 20 else current_key[10:]}")
    
    print()
    
    # Check .env file in project directory
    project_dir = Path(__file__).parent.parent
    env_file = project_dir / ".env"
    
    print(f"Checking .env file: {env_file}")
    print(f"  File exists: {'✅ YES' if env_file.exists() else '❌ NO'}")
    
    if env_file.exists():
        try:
            with open(env_file) as f:
                content = f.read()
                has_openai_key = 'OPENAI_API_KEY=' in content
                print(f"  Contains OPENAI_API_KEY: {'✅ YES' if has_openai_key else '❌ NO'}")
                
                if has_openai_key:
                    # Extract the key
                    for line in content.split('\n'):
                        if line.strip().startswith('OPENAI_API_KEY='):
                            key_value = line.split('=', 1)[1].strip('\'"')
                            if key_value and not key_value.startswith('#'):
                                print(f"  Key preview: {key_value[:10]}...{key_value[-10:] if len(key_value) > 20 else key_value[10:]}")
                            break
        except Exception as e:
            print(f"  Error reading file: {e}")
    
    print()
    
    # Try loading with python-dotenv
    try:
        from dotenv import load_dotenv
        print("Testing dotenv loading...")
        
        # Clear existing env var
        if 'OPENAI_API_KEY' in os.environ:
            original_key = os.environ['OPENAI_API_KEY']
            del os.environ['OPENAI_API_KEY']
        else:
            original_key = None
            
        # Try loading
        load_dotenv(env_file)
        loaded_key = os.getenv('OPENAI_API_KEY')
        print(f"  dotenv load result: {'✅ SUCCESS' if loaded_key else '❌ FAILED'}")
        
        # Restore original
        if original_key:
            os.environ['OPENAI_API_KEY'] = original_key
        elif 'OPENAI_API_KEY' in os.environ:
            del os.environ['OPENAI_API_KEY']
            
    except ImportError:
        print("❌ python-dotenv not available")
    except Exception as e:
        print(f"❌ dotenv loading failed: {e}")
    
    print()
    
    # Check systemd environment file (production)
    systemd_env = Path("/etc/snowscrape/env")
    print(f"Checking systemd env file: {systemd_env}")
    print(f"  File exists: {'✅ YES' if systemd_env.exists() else '❌ NO'}")
    
    if systemd_env.exists():
        try:
            with open(systemd_env) as f:
                content = f.read()
                has_openai_key = 'OPENAI_API_KEY=' in content
                print(f"  Contains OPENAI_API_KEY: {'✅ YES' if has_openai_key else '❌ NO'}")
        except PermissionError:
            print("  ⚠️  Permission denied (run with sudo to check)")
        except Exception as e:
            print(f"  Error reading file: {e}")
    
    print()
    print("💡 Recommendations:")
    if not current_key:
        if env_file.exists():
            print("  - The .env file exists but key isn't loaded. Check file format.")
            print("  - Ensure no extra quotes or spaces around the key value.")
        else:
            print("  - Create a .env file in the project root with: OPENAI_API_KEY=your-key-here")
        print("  - For production, ensure systemd environment file is set up correctly.")
    else:
        print("  ✅ OpenAI API key is properly loaded!")

if __name__ == "__main__":
    check_env_loading()