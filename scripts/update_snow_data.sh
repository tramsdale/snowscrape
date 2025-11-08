#!/bin/bash
# update_snow_data.sh - Run snow scraper with logging

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/scraper_$(date +%Y%m%d).log"
LOCK_FILE="$PROJECT_DIR/.scraper.lock"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "ERROR: Another scraper instance is already running (PID: $PID)"
        exit 1
    else
        log "WARNING: Stale lock file found, removing"
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
    log "Scraper finished"
}
trap cleanup EXIT

# Start scraping
log "Starting snow data scraper"
cd "$PROJECT_DIR"

# Activate virtual environment and run scraper
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    log "Virtual environment activated"
else
    log "ERROR: Virtual environment not found at .venv/bin/activate"
    exit 1
fi

# Run the actual scraper (not the placeholder main.py)
log "Running scraper..."
# Try the installed script first, fallback to module
if command -v scrape >/dev/null 2>&1; then
    if scrape >> "$LOG_FILE" 2>&1; then
        log "Scraper completed successfully"
    else
        log "ERROR: Scraper failed with exit code $?"
        exit 1
    fi
else
    log "ERROR: Scraper failed with exit code $?"
    exit 1
fi

# Check if output files were created
    if [ -f "out_snow/meta.json" ]; then
        # Use cross-platform date command instead of stat
        if command -v stat >/dev/null 2>&1; then
            # Try Linux/GNU stat first
            if stat --version >/dev/null 2>&1; then
                LAST_UPDATE=$(stat -c "%y" "out_snow/meta.json" 2>/dev/null | cut -d'.' -f1)
            else
                # macOS stat fallback
                LAST_UPDATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "out_snow/meta.json" 2>/dev/null)
            fi
        fi
        
        # If stat failed or not available, use ls
        if [ -z "$LAST_UPDATE" ]; then
            LAST_UPDATE=$(ls -la "out_snow/meta.json" | awk '{print $6, $7, $8}')
        fi
        
        log "Data last updated: $LAST_UPDATE"
    fi

# Log file sizes for monitoring
log "Output file sizes:"
find out_snow -name "*.json" -exec ls -lh {} \; | awk '{print $5, $9}' | tee -a "$LOG_FILE"

log "Scraper job completed"