#!/bin/bash
# setup_cron.sh - Setup cron job for snow data scraper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update_snow_data.sh"

# Make update script executable
chmod +x "$UPDATE_SCRIPT"

# Create cron job entry
CRON_ENTRY="0 * * * * $UPDATE_SCRIPT"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$UPDATE_SCRIPT"; then
    echo "Cron job already exists for snow scraper"
    echo "Current crontab entries for this script:"
    crontab -l | grep "$UPDATE_SCRIPT"
else
    # Add cron job
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "Cron job added successfully!"
    echo "Snow data will be updated every hour at minute 0"
    echo "Cron entry: $CRON_ENTRY"
fi

echo ""
echo "To view all cron jobs: crontab -l"
echo "To remove this cron job: crontab -e (then delete the line)"
echo "To view logs: tail -f ../logs/scraper_$(date +%Y%m%d).log"