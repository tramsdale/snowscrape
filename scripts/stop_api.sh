#!/bin/bash
# stop_api.sh - Stop the snow data API server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/.api.pid"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [ ! -f "$PID_FILE" ]; then
    log "No PID file found. API server may not be running."
    exit 0
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    log "Stopping API server (PID: $PID)..."
    kill "$PID"
    
    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            log "API server stopped successfully"
            rm -f "$PID_FILE"
            exit 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    log "Force killing API server..."
    kill -9 "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    log "API server force stopped"
else
    log "API server is not running"
    rm -f "$PID_FILE"
fi