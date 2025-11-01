#!/bin/bash
# setup_project.sh - Complete project setup script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[SETUP]${NC} $1"
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

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Snow Scraper Setup                       ║"
echo "║              Complete Project Initialization                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

# Make all scripts executable
print_status "Making scripts executable..."
chmod +x scripts/*.sh

# Check if we should set up GitHub
SETUP_GITHUB=false
GITHUB_REPO=""

read -p "Do you want to set up GitHub integration? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SETUP_GITHUB=true
    read -p "Enter GitHub repository (username/repo-name): " GITHUB_REPO
fi

# Run git setup
if [ "$SETUP_GITHUB" = true ] && [ -n "$GITHUB_REPO" ]; then
    print_status "Setting up git and GitHub..."
    ./scripts/setup_git.sh
    ./scripts/setup_github.sh "$GITHUB_REPO"
else
    print_status "Setting up git only..."
    ./scripts/setup_git.sh
fi

# Run deployment
print_status "Running deployment..."
./scripts/deploy.sh

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     Setup Complete!                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
print_success "Project setup completed successfully!"
echo ""
echo "What's been set up:"
echo "  ✓ Git repository initialized"
if [ "$SETUP_GITHUB" = true ]; then
echo "  ✓ GitHub repository connected"
fi
echo "  ✓ Virtual environment created"
echo "  ✓ Dependencies installed"
echo "  ✓ Cron job configured (hourly scraping)"
echo "  ✓ API server started on port 8001"
echo "  ✓ Logging configured"
echo ""
echo "Quick access:"
echo "  📊 API: http://localhost:8001"
echo "  📖 Docs: http://localhost:8001/docs"
echo "  ❤️  Health: http://localhost:8001/health"
echo ""
echo "Useful commands:"
echo "  📝 View logs: tail -f logs/scraper_\$(date +%Y%m%d).log"
echo "  🔄 Manual scrape: source .venv/bin/activate && python main.py"
echo "  🛑 Stop API: ./scripts/stop_api.sh"
if [ "$SETUP_GITHUB" = true ]; then
echo "  📤 Update GitHub: ./scripts/update_github.sh"
fi
echo ""
echo "Happy scraping! 🎿❄️"