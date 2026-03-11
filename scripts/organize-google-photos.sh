#!/bin/bash
# Extract and organize Google Photos Takeout ZIP files
# Organizes photos by date (YYYY/MM/DD) similar to iCloud structure

set -e

DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
OUTPUT_DIR="${GOOGLE_PHOTOS_ROOT:-/path/to/your/google-photos-library}"
TEMP_EXTRACT="/tmp/google-photos-extract"

# Image and video extensions to process
IMAGE_EXTS=("jpg" "jpeg" "png" "gif" "bmp" "webp" "heic" "heif" "cr2" "nef" "raw" "arw")
VIDEO_EXTS=("mov" "mp4" "avi" "mkv" "m4v" "mpg" "mpeg" "3gp" "webm" "flv")

echo "=========================================="
echo "Google Photos Organization Script"
echo "=========================================="
echo ""
echo "Downloads: $DOWNLOADS_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create temporary extraction directory
mkdir -p "$TEMP_EXTRACT"

# Function to get date from JSON metadata, EXIF, or file modification date
get_file_date() {
    local file="$1"
    local base="${file%.*}"
    local json_file="${base}.json"
    local supplemental_json="${base}.supplemental-metadata.json"
    
    # Try Google Photos JSON metadata first (most accurate for Takeout)
    for json in "$json_file" "$supplemental_json" "${base}.metadata.json"; do
        if [ -f "$json" ]; then
            # Extract photoTakenTime timestamp from JSON (Google Photos format)
            # JSON may have timestamp as string or number, photoTakenTime is preferred over creationTime
            if command -v python3 &> /dev/null; then
                date=$(python3 -c "
import json, sys, os
try:
    with open('$json', 'r') as f:
        data = json.load(f)
    # Try photoTakenTime first (actual photo date)
    ts = None
    if 'photoTakenTime' in data and 'timestamp' in data['photoTakenTime']:
        ts = data['photoTakenTime']['timestamp']
    elif 'creationTime' in data and 'timestamp' in data['creationTime']:
        ts = data['creationTime']['timestamp']
    if ts:
        # Handle both string and int timestamps
        ts = int(str(ts))
        from datetime import datetime
        dt = datetime.fromtimestamp(ts)
        print(dt.strftime('%Y/%m/%d'))
except:
    pass
" 2>/dev/null)
                if [ ! -z "$date" ] && [[ "$date" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
                    echo "$date"
                    return
                fi
            fi
        fi
    done
    
    # Try exiftool if available
    if command -v exiftool &> /dev/null; then
        date=$(exiftool -s -s -s -d "%Y/%m/%d" -DateTimeOriginal "$file" 2>/dev/null)
        if [ -z "$date" ]; then
            date=$(exiftool -s -s -s -d "%Y/%m/%d" -CreateDate "$file" 2>/dev/null)
        fi
        if [ -z "$date" ]; then
            date=$(exiftool -s -s -s -d "%Y/%m/%d" -ModifyDate "$file" 2>/dev/null)
        fi
        if [ ! -z "$date" ] && [[ "$date" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
            echo "$date"
            return
        fi
    fi
    
    # Try to extract year from folder name (Takeout structure: "Photos from YYYY")
    folder_year=$(echo "$file" | grep -oP "Photos from \K[0-9]{4}" | head -1)
    if [ ! -z "$folder_year" ]; then
        # Use file modification time for month/day, year from folder
        if stat -c "%Y" "$file" &>/dev/null; then
            mod_time=$(stat -c "%Y" "$file")
            month_day=$(date -d "@$mod_time" "+%m/%d" 2>/dev/null || date -r "$mod_time" "+%m/%d" 2>/dev/null)
            if [ ! -z "$month_day" ]; then
                echo "$folder_year/$month_day"
                return
            fi
        fi
        # Fallback: use middle of year
        echo "$folder_year/06/15"
        return
    fi
    
    # Final fallback to file modification time
    if stat -c "%Y" "$file" &>/dev/null; then
        mod_time=$(stat -c "%Y" "$file")
        date -d "@$mod_time" "+%Y/%m/%d" 2>/dev/null || date -r "$mod_time" "+%Y/%m/%d" 2>/dev/null || date "+%Y/%m/%d"
    else
        date "+%Y/%m/%d"
    fi
}

# Function to check if file is media
is_media_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"  # lowercase
    
    for image_ext in "${IMAGE_EXTS[@]}"; do
        if [ "$ext" = "$image_ext" ]; then
            return 0
        fi
    done
    
    for video_ext in "${VIDEO_EXTS[@]}"; do
        if [ "$ext" = "$video_ext" ]; then
            return 0
        fi
    done
    
    return 1
}

# Count ZIP files
zip_count=$(find "$DOWNLOADS_DIR" -maxdepth 1 -name "takeout-*.zip" | wc -l)
echo "Found $zip_count ZIP files to process"
echo ""

# Process each ZIP file
counter=0
for zip_file in "$DOWNLOADS_DIR"/takeout-*.zip; do
    counter=$((counter + 1))
    zip_name=$(basename "$zip_file")
    
    echo "[$counter/$zip_count] Processing: $zip_name"
    
    # Extract ZIP to temp directory
    echo "  Extracting..."
    unzip -q "$zip_file" -d "$TEMP_EXTRACT" 2>/dev/null || {
        echo "  Warning: Could not extract $zip_name"
        continue
    }
    
    # Find all media files in the extracted content
    echo "  Organizing media files..."
    file_count=0
    
    # Search in Google Photos folders (typical Takeout structure)
    while IFS= read -r -d '' file; do
        if ! is_media_file "$file"; then
            continue
        fi
        
        file_count=$((file_count + 1))
        
        # Get date for organization
        date_path=$(get_file_date "$file")
        
        # Create destination directory (YYYY/MM/DD)
        dest_dir="$OUTPUT_DIR/$date_path"
        mkdir -p "$dest_dir"
        
        # Copy file with original name (handle duplicates)
        filename=$(basename "$file")
        dest_file="$dest_dir/$filename"
        
        # If file exists, append counter
        if [ -f "$dest_file" ]; then
            base="${filename%.*}"
            ext="${filename##*.}"
            counter_suffix=1
            while [ -f "$dest_dir/${base}_${counter_suffix}.${ext}" ]; do
                counter_suffix=$((counter_suffix + 1))
            done
            dest_file="$dest_dir/${base}_${counter_suffix}.${ext}"
        fi
        
        cp "$file" "$dest_file"
        
        if [ $((file_count % 100)) -eq 0 ]; then
            echo "    Processed $file_count files..."
        fi
    done < <(find "$TEMP_EXTRACT" -type f -print0)
    
    echo "  Organized $file_count files from $zip_name"
    
    # Clean up extracted files for this ZIP
    echo "  Cleaning up..."
    rm -rf "$TEMP_EXTRACT"/*
    
    echo ""
done

# Final cleanup
rm -rf "$TEMP_EXTRACT"

echo "=========================================="
echo "Organization Complete!"
echo "=========================================="
echo ""
echo "Photos organized in: $OUTPUT_DIR"
echo "Structure: YYYY/MM/DD"
echo ""
echo "Summary:"
find "$OUTPUT_DIR" -type f | wc -l | xargs echo "Total files:"
find "$OUTPUT_DIR" -type d | wc -l | xargs echo "Total directories:"

