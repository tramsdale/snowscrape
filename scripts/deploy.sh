#!/bin/bash
# deploy.sh - Complete deployment script for snow scraper

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
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

# Parse command line arguments
ENVIRONMENT="development"
SKIP_DEPS=false
SETUP_CRON=true
START_API=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --no-cron)
            SETUP_CRON=false
            shift
            ;;
        --no-api)
            START_API=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --env ENV        Set environment (development|production) [default: development]"
            echo "  --skip-deps      Skip dependency installation"
            echo "  --no-cron        Skip cron job setup"
            echo "  --no-api         Skip API server startup"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "Starting deployment for $ENVIRONMENT environment..."
print_status "Project directory: $PROJECT_DIR"

cd "$PROJECT_DIR"

# Check if this is a git repository
if [ ! -d ".git" ]; then
    print_warning "Not a git repository. Consider running: git init"
fi

# Create necessary directories
print_status "Creating directory structure..."
mkdir -p logs
mkdir -p out_snow
mkdir -p scripts

# Make scripts executable
chmod +x scripts/*.sh 2>/dev/null || true

# Check Python and uv installation
print_status "Checking Python environment..."

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    exit 1
fi

if ! command -v uv &> /dev/null; then
    print_error "uv is not installed. Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Set up virtual environment
if [ ! -d ".venv" ]; then
    print_status "Creating virtual environment..."
    uv venv
fi

# Install dependencies
if [ "$SKIP_DEPS" = false ]; then
    print_status "Installing dependencies..."
    uv sync
    
    # Add API server dependencies
    print_status "Adding API server dependencies..."
    uv add fastapi uvicorn python-multipart
fi

# Verify main.py exists
if [ ! -f "main.py" ]; then
    print_error "main.py not found. This script should be run from the snowscrape project root."
    exit 1
fi

# Test the scraper
print_status "Testing scraper..."
source .venv/bin/activate

if python main.py --help &>/dev/null || python main.py &>/dev/null; then
    print_success "Scraper test completed"
else
    print_warning "Scraper test failed, but continuing deployment"
fi

# Setup cron job
if [ "$SETUP_CRON" = true ]; then
    print_status "Setting up cron job..."
    if [ -f "scripts/setup_cron.sh" ]; then
        chmod +x scripts/setup_cron.sh
        scripts/setup_cron.sh
        print_success "Cron job configured"
    else
        print_warning "Cron setup script not found"
    fi
fi

# Start API server
if [ "$START_API" = true ]; then
    print_status "Starting API server..."
    if [ -f "scripts/start_api.sh" ]; then
        chmod +x scripts/start_api.sh
        scripts/start_api.sh
        print_success "API server started"
    else
        print_warning "API start script not found"
    fi
fi

# Create systemd service for production
if [ "$ENVIRONMENT" = "production" ]; then
    print_status "Creating systemd service..."
    
    SERVICE_NAME="snowscrape"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Snow Scraper API Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/.venv/bin
ExecStart=$PROJECT_DIR/.venv/bin/python $PROJECT_DIR/api_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    print_success "Systemd service created and started"
fi

# Display deployment summary
print_success "Deployment completed!"
echo ""
echo "Summary:"
echo "  - Project directory: $PROJECT_DIR"
echo "  - Environment: $ENVIRONMENT"
echo "  - Logs directory: $PROJECT_DIR/logs"
echo "  - Data directory: $PROJECT_DIR/out_snow"

if [ "$SETUP_CRON" = true ]; then
    echo "  - Cron job: Scraper runs every hour"
fi

if [ "$START_API" = true ]; then
    echo "  - API server: http://localhost:8001"
    echo "  - API docs: http://localhost:8001/docs"
fi

echo ""
echo "Useful commands:"
echo "  - View scraper logs: tail -f logs/scraper_\$(date +%Y%m%d).log"
echo "  - View API logs: tail -f logs/api_\$(date +%Y%m%d).log"
echo "  - Stop API: scripts/stop_api.sh"
echo "  - Manual scrape: source .venv/bin/activate && python main.py"
echo "  - View cron jobs: crontab -l"

if [ "$ENVIRONMENT" = "production" ]; then
    echo "  - Service status: sudo systemctl status snowscrape"
    echo "  - Service logs: sudo journalctl -u snowscrape -f"
fi