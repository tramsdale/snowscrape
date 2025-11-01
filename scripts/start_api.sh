#!/bin/bash
# start_api.sh - Start the snow data API server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/.api.pid"

# Create logs directory
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "API server is already running (PID: $PID)"
        log "Access it at: http://localhost:8001"
        exit 0
    else
        log "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

cd "$PROJECT_DIR"

# Check if virtual environment exists
if [ ! -f ".venv/bin/activate" ]; then
    log "ERROR: Virtual environment not found. Run setup_project.sh first"
    exit 1
fi

# Activate virtual environment
source .venv/bin/activate

# Check if FastAPI is installed
if ! python -c "import fastapi" 2>/dev/null; then
    log "Installing FastAPI and dependencies..."
    uv add fastapi uvicorn
fi

# Start the API server
log "Starting snow data API server on port 8001..."
nohup python api_server.py > "$LOG_DIR/api_$(date +%Y%m%d).log" 2>&1 &
API_PID=$!

# Save PID
echo $API_PID > "$PID_FILE"

# Wait a moment and check if it started successfully
sleep 2
if ps -p $API_PID > /dev/null 2>&1; then
    log "API server started successfully (PID: $API_PID)"
    log "Access the API at: http://localhost:8001"
    log "API documentation at: http://localhost:8001/docs"
    log "Health check: http://localhost:8001/health"
    log ""
    log "To stop the server: ./scripts/stop_api.sh"
    log "To view logs: tail -f logs/api_$(date +%Y%m%d).log"
else
    log "ERROR: Failed to start API server"
    rm -f "$PID_FILE"
    exit 1
fi