#!/usr/bin/env bash
################################################################################
# Cleanup Downloads Script
# 
# Purpose: Automatically removes old files from the downloads folder to free
#          up space after qBittorrent has finished seeding.
#
# Usage: ./scripts/cleanup-downloads.sh
#        Or run via cron for automated cleanup
#
# What it does:
#   - Deletes files older than 7 days from downloads/complete/
#   - Preserves active torrents (qBittorrent removes these anyway)
#   - Safe: Only touches downloads folder, never your media library
#
# Note: If you configured qBittorrent to "Remove torrent and files" after
#       seeding, this script is redundant but acts as a safety net.
################################################################################
# Cleanup completed downloads after seeding period
# Removes files from /downloads/complete/ that are older than 24 hours
# and no longer being seeded by qBittorrent

set -euo pipefail

DOWNLOADS_DIR="/downloads/complete"
AGE_DAYS=1  # Files older than 1 day

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "=== Starting download cleanup ==="

# Check if downloads directory exists
if [ ! -d "$DOWNLOADS_DIR" ]; then
    log "ERROR: Downloads directory not found: $DOWNLOADS_DIR"
    exit 1
fi

# Find and remove directories older than AGE_DAYS
# This is safe because Radarr/Sonarr have already imported the files
# and created hardlinks in the media directories

REMOVED_COUNT=0
FREED_SPACE=0

while IFS= read -r -d '' dir; do
    # Get directory name and size
    DIR_NAME=$(basename "$dir")
    DIR_SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
    
    # Skip if directory is currently being written to (has .!qb files)
    if find "$dir" -name "*.!qb" -o -name "*.part" 2>/dev/null | grep -q .; then
        log "SKIP: $DIR_NAME (download in progress)"
        continue
    fi
    
    # Check age
    DIR_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$dir") ))
    DIR_AGE_HOURS=$(( DIR_AGE_SECONDS / 3600 ))
    
    if [ $DIR_AGE_HOURS -ge 24 ]; then
        log "REMOVE: $DIR_NAME (age: ${DIR_AGE_HOURS}h, size: $(numfmt --to=iec $DIR_SIZE 2>/dev/null || echo "$DIR_SIZE bytes"))"
        rm -rf "$dir"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
        FREED_SPACE=$((FREED_SPACE + DIR_SIZE))
    else
        log "KEEP: $DIR_NAME (age: ${DIR_AGE_HOURS}h, too recent)"
    fi
done < <(find "$DOWNLOADS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# Summary
if [ $REMOVED_COUNT -gt 0 ]; then
    FREED_GB=$(echo "scale=2; $FREED_SPACE / 1073741824" | bc)
    log "=== Cleanup complete: Removed $REMOVED_COUNT items, freed ${FREED_GB}GB ==="
else
    log "=== Cleanup complete: Nothing to remove ==="
fi

