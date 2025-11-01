#!/bin/bash
# update_github.sh - Update GitHub repository with latest changes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[UPDATE]${NC} $1"
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

cd "$PROJECT_DIR"

# Check if this is a git repository
if [ ! -d ".git" ]; then
    print_error "Not a git repository. Run ./scripts/setup_git.sh first"
    exit 1
fi

# Check if remote exists
if ! git remote get-url origin &>/dev/null; then
    print_error "No 'origin' remote found. Run ./scripts/setup_github.sh first"
    exit 1
fi

# Get commit message from user or use default
COMMIT_MSG=""
if [ $# -eq 0 ]; then
    # Generate automatic commit message based on changes
    if git diff --cached --quiet && git diff --quiet; then
        print_warning "No changes to commit"
        exit 0
    fi
    
    # Check what types of files changed
    CHANGED_FILES=$(git status --porcelain | wc -l | tr -d ' ')
    
    if [ "$CHANGED_FILES" -gt 0 ]; then
        print_status "Found $CHANGED_FILES changed files"
        
        # Show status
        git status --short
        
        echo ""
        read -p "Enter commit message (or press Enter for auto-generated): " COMMIT_MSG
        
        if [ -z "$COMMIT_MSG" ]; then
            COMMIT_MSG="Update: $CHANGED_FILES files modified on $(date +%Y-%m-%d)"
        fi
    fi
else
    COMMIT_MSG="$*"
fi

# Add all changes
print_status "Adding changes..."
git add .

# Check if there are changes to commit
if git diff --cached --quiet; then
    print_warning "No staged changes to commit"
    exit 0
fi

# Commit changes
print_status "Committing changes..."
if git commit -m "$COMMIT_MSG"; then
    print_success "Changes committed: $COMMIT_MSG"
else
    print_error "Failed to commit changes"
    exit 1
fi

# Pull latest changes from remote (in case others have pushed)
print_status "Pulling latest changes from remote..."
if git pull --rebase origin main 2>/dev/null || git pull --rebase origin master 2>/dev/null; then
    print_success "Successfully pulled latest changes"
else
    print_warning "No remote changes to pull (or conflicts)"
fi

# Push changes
print_status "Pushing to GitHub..."
if git push; then
    print_success "Successfully pushed to GitHub!"
    
    # Get the repository URL
    REPO_URL=$(git remote get-url origin | sed 's/\.git$//')
    if [[ "$REPO_URL" == https://github.com/* ]]; then
        echo ""
        echo "View changes at: $REPO_URL"
    fi
else
    print_error "Failed to push to GitHub"
    print_error "You may need to resolve conflicts or check your credentials"
    exit 1
fi

# Show recent commits
echo ""
print_status "Recent commits:"
git log --oneline -5

echo ""
print_success "GitHub update completed!"