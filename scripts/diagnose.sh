#!/bin/bash
# diagnose.sh - Diagnose API server startup issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Snow Scraper API Diagnostics ==="
echo "Project directory: $PROJECT_DIR"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo ""

cd "$PROJECT_DIR"

# Check Python
echo "=== Python Environment ==="
if command -v python3 &> /dev/null; then
    echo "✓ Python 3 found: $(python3 --version)"
else
    echo "✗ Python 3 not found"
fi

if [ -f ".venv/bin/activate" ]; then
    echo "✓ Virtual environment found"
    source .venv/bin/activate
    echo "  Python: $(which python)"
    echo "  Version: $(python --version)"
else
    echo "✗ Virtual environment not found"
fi

# Check directories
echo ""
echo "=== Directory Structure ==="
for dir in "out_snow" "static" "logs" "scripts"; do
    if [ -d "$dir" ]; then
        echo "✓ $dir/ exists"
    else
        echo "✗ $dir/ missing"
        mkdir -p "$dir"
        echo "  → Created $dir/"
    fi
done

# Check required files
echo ""
echo "=== Required Files ==="
for file in "api_server.py" "main.py" "pyproject.toml"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
    fi
done

# Check Python dependencies
echo ""
echo "=== Python Dependencies ==="
if source .venv/bin/activate 2>/dev/null; then
    for pkg in "fastapi" "uvicorn" "playwright" "pandas" "beautifulsoup4"; do
        if python -c "import $pkg" 2>/dev/null; then
            version=$(python -c "import $pkg; print(getattr($pkg, '__version__', 'unknown'))" 2>/dev/null)
            echo "✓ $pkg ($version)"
        else
            echo "✗ $pkg missing"
        fi
    done
else
    echo "✗ Cannot activate virtual environment"
fi

# Check port availability
echo ""
echo "=== Port Check ==="
if command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":8001 "; then
        echo "✗ Port 8001 already in use:"
        netstat -tuln | grep ":8001 "
    else
        echo "✓ Port 8001 available"
    fi
elif command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":8001 "; then
        echo "✗ Port 8001 already in use:"
        ss -tuln | grep ":8001 "
    else
        echo "✓ Port 8001 available"
    fi
else
    echo "? Cannot check port (netstat/ss not available)"
fi

# Check recent logs
echo ""
echo "=== Recent Logs ==="
if [ -d "logs" ]; then
    latest_log=$(ls -t logs/api_*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ]; then
        echo "Latest API log: $latest_log"
        echo "Last 10 lines:"
        tail -10 "$latest_log"
    else
        echo "No API logs found"
    fi
else
    echo "No logs directory"
fi

# Test API server (dry run)
echo ""
echo "=== API Server Test ==="
if source .venv/bin/activate 2>/dev/null; then
    echo "Testing API server import..."
    python -c "
try:
    import api_server
    print('✓ API server imports successfully')
    
    # Test app creation
    app = api_server.app
    print('✓ FastAPI app created successfully')
    
except Exception as e:
    print(f'✗ API server test failed: {e}')
    import traceback
    traceback.print_exc()
" 2>&1
else
    echo "✗ Cannot test - virtual environment not available"
fi

echo ""
echo "=== Diagnostic Complete ==="
echo "If issues persist, check:"
echo "1. Virtual environment: source .venv/bin/activate"
echo "2. Install deps: uv sync"
echo "3. Manual start: python api_server.py"
echo "4. Check logs: tail -f logs/api_*.log"