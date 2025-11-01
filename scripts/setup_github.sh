#!/bin/bash
# setup_github.sh - Setup GitHub repository and push code

if [ $# -eq 0 ]; then
    echo "Usage: $0 <username/repository-name>"
    echo "Example: $0 yourusername/snowscrape"
    exit 1
fi

REPO_PATH="$1"
GITHUB_URL="https://github.com/${REPO_PATH}.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[GITHUB]${NC} $1"
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

# Check if git is initialized
if [ ! -d ".git" ]; then
    print_status "Initializing git first..."
    ./scripts/setup_git.sh
fi

# Check if remote already exists
if git remote get-url origin &>/dev/null; then
    EXISTING_URL=$(git remote get-url origin)
    print_warning "Remote 'origin' already exists: $EXISTING_URL"
    read -p "Do you want to update it to $GITHUB_URL? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin "$GITHUB_URL"
        print_success "Remote URL updated"
    else
        print_status "Keeping existing remote URL"
        GITHUB_URL="$EXISTING_URL"
    fi
else
    print_status "Adding GitHub remote..."
    git remote add origin "$GITHUB_URL"
fi

# Check if we have uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_status "Committing pending changes..."
    git add .
    git commit -m "Update before pushing to GitHub"
fi

# Push to GitHub
print_status "Pushing to GitHub..."
if git push -u origin main; then
    print_success "Successfully pushed to GitHub!"
else
    # Try pushing to master if main doesn't work
    print_warning "Failed to push to 'main', trying 'master'..."
    if git push -u origin master; then
        print_success "Successfully pushed to GitHub (master branch)!"
    else
        print_error "Failed to push to GitHub"
        print_error "You may need to:"
        print_error "1. Create the repository on GitHub first"
        print_error "2. Check your GitHub credentials"
        print_error "3. Verify the repository name is correct"
        exit 1
    fi
fi

echo ""
print_success "GitHub setup completed!"
echo ""
echo "Repository URL: https://github.com/${REPO_PATH}"
echo "Clone URL: $GITHUB_URL"
echo ""
echo "To update the repository in the future:"
echo "  git add ."
echo "  git commit -m 'Your commit message'"
echo "  git push"
echo ""
echo "Or use the update script:"
echo "  ./scripts/update_github.sh"