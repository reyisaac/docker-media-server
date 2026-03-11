#!/bin/bash

# iCloud Backup Verification Script
# This script checks the completeness of your iCloud photo/video backup

set -e

BACKUP_DIR="${ICLOUD_BACKUP_ROOT:-/path/to/your/icloud/backup}"
REPORT_FILE="/tmp/icloud-backup-report-$(date +%Y%m%d-%H%M%S).txt"

echo "=========================================="
echo "iCloud Backup Verification Report"
echo "Generated: $(date)"
echo "=========================================="
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo "Backup Location: $BACKUP_DIR"
echo ""

# Overall statistics
echo "=== OVERALL STATISTICS ==="
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total Backup Size: $TOTAL_SIZE"

TOTAL_FILES=$(find "$BACKUP_DIR" -type f | wc -l)
echo "Total Files: $TOTAL_FILES"

PHOTO_FILES=$(find "$BACKUP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.heif" \) | wc -l)
echo "Photo Files: $PHOTO_FILES"

VIDEO_FILES=$(find "$BACKUP_DIR" -type f \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" \) | wc -l)
echo "Video Files: $VIDEO_FILES"

OTHER_FILES=$((TOTAL_FILES - PHOTO_FILES - VIDEO_FILES))
echo "Other Files: $OTHER_FILES"
echo ""

# Year-by-year breakdown
echo "=== YEAR-BY-YEAR BREAKDOWN ==="
for year in $(ls -d "$BACKUP_DIR"/20* 2>/dev/null | xargs -n1 basename | sort); do
    year_dir="$BACKUP_DIR/$year"
    if [ -d "$year_dir" ]; then
        year_files=$(find "$year_dir" -type f | wc -l)
        year_size=$(du -sh "$year_dir" | cut -f1)
        year_photos=$(find "$year_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.heif" \) | wc -l)
        year_videos=$(find "$year_dir" -type f \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" \) | wc -l)
        echo "$year: $year_files files ($year_size) - $year_photos photos, $year_videos videos"
    fi
done
echo ""

# Check for recent activity
echo "=== RECENT ACTIVITY ==="
echo "Most recently modified files (last 10):"
find "$BACKUP_DIR" -type f -printf "%T@ %Tc %p\n" | sort -rn | head -10 | while read timestamp date time file; do
    echo "  $(echo $date $time | cut -d' ' -f1-2): $(basename "$file")"
done
echo ""

# Check for potential issues
echo "=== POTENTIAL ISSUES ==="
ISSUES=0

# Check if 2025 has files (current year)
if [ -d "$BACKUP_DIR/2025" ]; then
    current_year_files=$(find "$BACKUP_DIR/2025" -type f | wc -l)
    if [ "$current_year_files" -eq 0 ]; then
        echo "WARNING: 2025 directory exists but is empty"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "INFO: 2025 directory does not exist yet (may be normal if no photos this year)"
fi

# Check for empty directories
EMPTY_DIRS=$(find "$BACKUP_DIR" -type d -empty | wc -l)
if [ "$EMPTY_DIRS" -gt 0 ]; then
    echo "WARNING: Found $EMPTY_DIRS empty directories"
    ISSUES=$((ISSUES + 1))
fi

# Check Docker container status
if docker ps --format "{{.Names}}" | grep -q "^icloudpd$"; then
    CONTAINER_STATUS=$(docker inspect icloudpd --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$CONTAINER_STATUS" != "healthy" ]; then
        echo "WARNING: icloudpd container is $CONTAINER_STATUS"
        echo "  This may indicate authentication issues. Check with: docker logs icloudpd"
        ISSUES=$((ISSUES + 1))
    else
        echo "INFO: icloudpd container is healthy"
    fi
else
    echo "WARNING: icloudpd container is not running"
    ISSUES=$((ISSUES + 1))
fi

if [ "$ISSUES" -eq 0 ]; then
    echo "No issues detected!"
fi
echo ""

# File type distribution
echo "=== FILE TYPE DISTRIBUTION ==="
echo "Photo formats:"
find "$BACKUP_DIR" -type f -iname "*.jpg" | wc -l | xargs echo "  JPG:"
find "$BACKUP_DIR" -type f -iname "*.jpeg" | wc -l | xargs echo "  JPEG:"
find "$BACKUP_DIR" -type f -iname "*.png" | wc -l | xargs echo "  PNG:"
find "$BACKUP_DIR" -type f -iname "*.heic" | wc -l | xargs echo "  HEIC:"
find "$BACKUP_DIR" -type f -iname "*.heif" | wc -l | xargs echo "  HEIF:"
echo ""
echo "Video formats:"
find "$BACKUP_DIR" -type f -iname "*.mov" | wc -l | xargs echo "  MOV:"
find "$BACKUP_DIR" -type f -iname "*.mp4" | wc -l | xargs echo "  MP4:"
find "$BACKUP_DIR" -type f -iname "*.m4v" | wc -l | xargs echo "  M4V:"
echo ""

# Summary
echo "=== SUMMARY ==="
echo "Your iCloud backup contains:"
echo "  - $TOTAL_FILES total files"
echo "  - $PHOTO_FILES photos"
echo "  - $VIDEO_FILES videos"
echo "  - Total size: $TOTAL_SIZE"
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""

# Save report
{
    echo "=========================================="
    echo "iCloud Backup Verification Report"
    echo "Generated: $(date)"
    echo "=========================================="
    echo ""
    echo "Backup Location: $BACKUP_DIR"
    echo "Total Size: $TOTAL_SIZE"
    echo "Total Files: $TOTAL_FILES"
    echo "Photo Files: $PHOTO_FILES"
    echo "Video Files: $VIDEO_FILES"
} > "$REPORT_FILE"

echo "To fix authentication issues, run:"
echo "  docker exec -it icloudpd sync-icloud.sh --Initialise"

