#!/bin/bash

echo "=== Checking Snow Service Status ==="

# Check if systemd service exists and is running
if systemctl list-units --full -all | grep -Fq "snowscrape.service"; then
    echo "🔍 Found snowscrape.service"
    echo "Status:"
    systemctl status snowscrape.service
    echo ""
    echo "To stop the service: sudo systemctl stop snowscrape.service"
    echo "To disable auto-start: sudo systemctl disable snowscrape.service"
    echo ""
fi

# Check for processes using port 8001
echo "=== Checking Port 8001 Usage ==="
PORT_CHECK=$(lsof -i :8001 2>/dev/null)
if [ -n "$PORT_CHECK" ]; then
    echo "⚠️  Port 8001 is in use:"
    echo "$PORT_CHECK"
    echo ""
    PID=$(echo "$PORT_CHECK" | awk 'NR==2 {print $2}')
    if [ -n "$PID" ]; then
        echo "To kill the process: kill $PID"
    fi
else
    echo "✅ Port 8001 is available"
fi

# Check for any python processes that might be the API server
echo ""
echo "=== Checking Python API Processes ==="
API_PROCESSES=$(ps aux | grep "[a]pi_server.py")
if [ -n "$API_PROCESSES" ]; then
    echo "🔍 Found API server processes:"
    echo "$API_PROCESSES"
    echo ""
    echo "To kill all: pkill -f api_server.py"
else
    echo "✅ No api_server.py processes found"
fi

# Check PID file
echo ""
echo "=== Checking PID File ==="
if [ -f "logs/api_server.pid" ]; then
    PID_FROM_FILE=$(cat logs/api_server.pid)
    echo "📁 PID file exists: $PID_FROM_FILE"
    if ps -p $PID_FROM_FILE > /dev/null 2>&1; then
        echo "⚠️  Process $PID_FROM_FILE is still running"
        echo "To kill: kill $PID_FROM_FILE"
    else
        echo "💀 Process $PID_FROM_FILE is not running (stale PID file)"
        echo "To clean up: rm logs/api_server.pid"
    fi
else
    echo "✅ No PID file found"
fi

echo ""
echo "=== Summary ==="
echo "If service is running: sudo systemctl stop snowscrape.service"
echo "If port is busy: kill the process using the port"
echo "If PID file exists: rm logs/api_server.pid"
echo "Then try: ./scripts/start_api.sh"