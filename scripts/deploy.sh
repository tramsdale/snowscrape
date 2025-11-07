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

# Stop existing services before starting new ones
if [ "$START_API" = true ]; then
    print_status "Checking for existing services..."
    
    # Stop systemd service if it exists
    if systemctl list-units --full -all | grep -Fq "snowscrape.service"; then
        print_status "Stopping existing systemd service..."
        sudo systemctl stop snowscrape.service || print_warning "Failed to stop systemd service"
    fi
    
    # Kill any processes using port 8001
    PORT_PROCESSES=$(lsof -ti :8001 2>/dev/null || true)
    if [ -n "$PORT_PROCESSES" ]; then
        print_status "Stopping processes using port 8001..."
        echo "$PORT_PROCESSES" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        # Force kill if still running
        PORT_PROCESSES=$(lsof -ti :8001 2>/dev/null || true)
        if [ -n "$PORT_PROCESSES" ]; then
            echo "$PORT_PROCESSES" | xargs kill -KILL 2>/dev/null || true
        fi
    fi
    
    # Kill any existing api_server.py processes
    API_PIDS=$(pgrep -f "api_server.py" 2>/dev/null || true)
    if [ -n "$API_PIDS" ]; then
        print_status "Stopping existing API server processes..."
        echo "$API_PIDS" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        # Force kill if still running
        API_PIDS=$(pgrep -f "api_server.py" 2>/dev/null || true)
        if [ -n "$API_PIDS" ]; then
            echo "$API_PIDS" | xargs kill -KILL 2>/dev/null || true
        fi
    fi
    
    # Clean up stale PID file
    if [ -f "logs/api_server.pid" ]; then
        print_status "Cleaning up stale PID file..."
        rm -f logs/api_server.pid
    fi
    
    print_success "Existing services stopped"
    
    # Start API server
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
    print_status "Setting up systemd service..."
    
    SERVICE_NAME="snowscrape"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    ENV_FILE="/etc/snowscrape/env"
    
    # Stop and disable existing service if it exists
    if systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        print_status "Stopping existing systemd service..."
        sudo systemctl stop "$SERVICE_NAME" || true
        sudo systemctl disable "$SERVICE_NAME" || true
    fi
    
    # Setup OpenAI API key environment file
    print_status "Setting up OpenAI API key..."
    if [ ! -f "$ENV_FILE" ]; then
        print_status "Creating secure environment file..."
        sudo mkdir -p "$(dirname "$ENV_FILE")"
        
        # Check if we can find the key in existing .env file
        EXISTING_KEY=""
        if [ -f ".env" ]; then
            EXISTING_KEY=$(grep "^OPENAI_API_KEY=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
        fi
        
        if [ -n "$EXISTING_KEY" ]; then
            print_status "Found existing OpenAI API key in .env file, copying to secure location..."
            sudo tee "$ENV_FILE" > /dev/null <<EOF
OPENAI_API_KEY=$EXISTING_KEY
EOF
        else
            print_warning "OpenAI API key not found. Please set it manually:"
            print_warning "  sudo nano $ENV_FILE"
            print_warning "  Add: OPENAI_API_KEY=sk-your-key-here"
            # Create empty file with placeholder
            sudo tee "$ENV_FILE" > /dev/null <<EOF
# Add your OpenAI API key here:
# OPENAI_API_KEY=sk-your-key-here
EOF
        fi
        
        # Set secure permissions
        sudo chmod 600 "$ENV_FILE"
        sudo chown root:root "$ENV_FILE"
        print_success "Environment file created at $ENV_FILE"
    else
        print_success "Environment file already exists at $ENV_FILE"
    fi
    
    print_status "Creating systemd service..."
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Snow Scraper API Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/.venv/bin
EnvironmentFile=$ENV_FILE
ExecStart=$PROJECT_DIR/.venv/bin/python $PROJECT_DIR/api_server.py --production
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    # Verify the service started and has the API key
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Systemd service created and started"
        
        # Check if API key is available (basic verification)
        if sudo grep -q "^OPENAI_API_KEY=sk-" "$ENV_FILE" 2>/dev/null; then
            print_success "OpenAI API key configured"
        else
            print_warning "OpenAI API key may not be set correctly in $ENV_FILE"
        fi
    else
        print_error "Service failed to start. Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
    fi
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
    echo "  - Edit API key: sudo nano /etc/snowscrape/env"
    echo "  - Restart after key change: sudo systemctl restart snowscrape"
fi