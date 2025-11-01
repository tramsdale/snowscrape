#!/bin/bash
# setup_git.sh - Initialize git repository and prepare for GitHub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[GIT]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

cd "$PROJECT_DIR"

# Check if already a git repository
if [ -d ".git" ]; then
    print_warning "Already a git repository"
    git status
    exit 0
fi

print_status "Initializing git repository..."

# Initialize git
git init

# Create .gitignore
print_status "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual Environment
.venv/
venv/
ENV/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
logs/
*.log

# Runtime files
*.pid
.api.pid
.scraper.lock

# Output data (optional - you might want to track some of this)
out_snow/*.html
out_snow/*.csv

# Environment variables
.env
.env.local

# macOS
.DS_Store

# Temporary files
*.tmp
*.temp

# Backup files
*.bak
*~
EOF

# Create README.md
print_status "Creating README.md..."
cat > README.md << 'EOF'
# Snow Scraper

A Python application that scrapes snow forecast data and serves it via a REST API.

## Features

- Automated snow forecast data scraping
- JSON and CSV data export
- RESTful API server with FastAPI
- Automated deployment with cron job scheduling
- Comprehensive logging and monitoring

## Quick Start

### 1. Deploy the application
```bash
./scripts/deploy.sh
```

### 2. Access the API
- API endpoints: http://localhost:8001
- Interactive docs: http://localhost:8001/docs
- Health check: http://localhost:8001/health

### 3. View data
```bash
# List available data files
curl http://localhost:8001/files

# Get snow summary
curl http://localhost:8001/snow/summary

# Get dynamic forecast
curl http://localhost:8001/forecast/dynamic
```

## Manual Operations

### Run scraper manually
```bash
source .venv/bin/activate
python main.py
```

### Start/stop API server
```bash
./scripts/start_api.sh
./scripts/stop_api.sh
```

### Setup cron job
```bash
./scripts/setup_cron.sh
```

## Development

### Requirements
- Python 3.8+
- uv package manager

### Setup development environment
```bash
# Clone repository
git clone <your-repo-url>
cd snowscrape

# Deploy in development mode
./scripts/deploy.sh --env development
```

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /meta` - Scraper metadata
- `GET /forecast/dynamic` - Dynamic forecast data
- `GET /forecast/hourly` - Hourly forecast data
- `GET /snow/summary` - Snow summary
- `GET /files` - List all data files
- `GET /files/{filename}` - Download specific file
- `GET /logs` - Recent log entries

## Production Deployment

```bash
./scripts/deploy.sh --env production
```

This will:
- Set up systemd service
- Configure automatic startup
- Enable production monitoring

## Monitoring

### View logs
```bash
# Scraper logs
tail -f logs/scraper_$(date +%Y%m%d).log

# API logs  
tail -f logs/api_$(date +%Y%m%d).log

# System service logs (production)
sudo journalctl -u snowscrape -f
```

### Check status
```bash
# API health
curl http://localhost:8001/health

# Cron jobs
crontab -l

# Service status (production)
sudo systemctl status snowscrape
```

## Directory Structure

```
snowscrape/
├── main.py              # Main scraper script
├── api_server.py        # FastAPI server
├── pyproject.toml       # Project dependencies
├── README.md           # This file
├── scripts/            # Deployment and utility scripts
│   ├── deploy.sh       # Main deployment script
│   ├── setup_cron.sh   # Cron job setup
│   ├── start_api.sh    # Start API server
│   ├── stop_api.sh     # Stop API server
│   └── update_snow_data.sh # Cron job script
├── out_snow/           # Generated data files
│   ├── *.json         # JSON data exports
│   └── *.csv          # CSV data exports
└── logs/              # Application logs
```

## License

[Add your license here]
EOF

# Add files to git
print_status "Adding files to git..."
git add .
git commit -m "Initial commit: Snow scraper with API server and deployment scripts"

print_success "Git repository initialized!"
echo ""
echo "Next steps:"
echo "1. Create a GitHub repository"
echo "2. Add remote: git remote add origin https://github.com/yourusername/snowscrape.git"
echo "3. Push to GitHub: git push -u origin main"
echo ""
echo "Or run the GitHub setup script:"
echo "  ./scripts/setup_github.sh yourusername/snowscrape"