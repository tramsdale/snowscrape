#!/bin/bash
# force_restart.sh - Aggressively stop all snowscrape processes and restart

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[RESTART]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Force stopping all snowscrape processes..."

# Stop systemd service first
if systemctl is-active --quiet snowscrape 2>/dev/null; then
    print_status "Stopping systemd service..."
    sudo systemctl stop snowscrape || print_warning "Failed to stop service gracefully"
fi

# Kill everything using port 8001 (multiple attempts)
for i in {1..3}; do
    PORT_PIDS=$(sudo lsof -ti :8001 2>/dev/null || true)
    if [ -n "$PORT_PIDS" ]; then
        print_status "Attempt $i: Killing processes on port 8001: $PORT_PIDS"
        echo "$PORT_PIDS" | xargs sudo kill -KILL 2>/dev/null || true
        sleep 2
    else
        print_success "Port 8001 is now free"
        break
    fi
done

# Kill all api_server.py processes (multiple attempts)
for i in {1..3}; do
    API_PIDS=$(sudo pgrep -f "api_server.py" 2>/dev/null || true)
    if [ -n "$API_PIDS" ]; then
        print_status "Attempt $i: Killing api_server.py processes: $API_PIDS"
        echo "$API_PIDS" | xargs sudo kill -KILL 2>/dev/null || true
        sleep 2
    else
        print_success "No api_server.py processes running"
        break
    fi
done

# Kill any python processes in our directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON_PIDS=$(sudo pgrep -f "$PROJECT_DIR" 2>/dev/null || true)
if [ -n "$PYTHON_PIDS" ]; then
    print_status "Killing python processes in project directory: $PYTHON_PIDS"
    echo "$PYTHON_PIDS" | xargs sudo kill -KILL 2>/dev/null || true
    sleep 1
fi

# Clean up PID files
print_status "Cleaning up PID files..."
rm -f "$PROJECT_DIR/logs/api_server.pid" 2>/dev/null || true

# Final check
PORT_CHECK=$(sudo lsof -i :8001 2>/dev/null || true)
if [ -n "$PORT_CHECK" ]; then
    print_error "Port 8001 is still in use:"
    echo "$PORT_CHECK"
    print_error "You may need to reboot the server"
    exit 1
fi

print_success "All processes stopped successfully"

# Restart the service
print_status "Starting snowscrape service..."
sudo systemctl start snowscrape

sleep 3

# Check if it started
if systemctl is-active --quiet snowscrape; then
    print_success "Snowscrape service started successfully!"
    
    # Show status
    sudo systemctl status snowscrape --no-pager -l
    
    print_status "Testing API endpoint..."
    if curl -f http://localhost:8001/forecast >/dev/null 2>&1; then
        print_success "API is responding!"
    else
        print_warning "API may not be fully ready yet"
    fi
else
    print_error "Service failed to start. Checking logs..."
    sudo journalctl -u snowscrape -n 20 --no-pager
    exit 1
fi