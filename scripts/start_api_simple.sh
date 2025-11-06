#!/bin/bash
# start_api_simple.sh - Simple API server start with better error handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Snow Forecast API server..."

# Create required directories
mkdir -p out_snow static logs

# Check virtual environment
if [ ! -f ".venv/bin/activate" ]; then
    echo "ERROR: Virtual environment not found at .venv/"
    echo "Run: uv venv && uv sync"
    exit 1
fi

# Activate virtual environment
source .venv/bin/activate

# Check if required packages are installed
python -c "
import sys
missing = []
for pkg in ['fastapi', 'uvicorn']:
    try:
        __import__(pkg)
    except ImportError:
        missing.append(pkg)

if missing:
    print(f'ERROR: Missing packages: {missing}')
    print('Run: uv add fastapi uvicorn')
    sys.exit(1)
    
print('✓ All required packages found')
"

if [ $? -ne 0 ]; then
    exit 1
fi

# Set production environment
export ENVIRONMENT=production

# Start the API server
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching API server on port 8001..."
exec python api_server.py --production