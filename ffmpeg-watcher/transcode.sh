#!/bin/bash
set -euo pipefail

# ============================================================================
# FFmpeg NVENC Auto-Transcoder
# Watches media folders and transcodes to HEVC using NVIDIA GPU
# ============================================================================

# Environment variables with defaults
NV_CQ="${NV_CQ:-23}"
NV_PRESET="${NV_PRESET:-p5}"
KEEP_HDR="${KEEP_HDR:-1}"
OUTPUT_EXT="${OUTPUT_EXT:-mkv}"
CONCURRENT_LIMIT="${CONCURRENT_LIMIT:-2}"
REENCODE_BLOATED_HEVC="${REENCODE_BLOATED_HEVC:-1}"  # Re-encode inefficient HEVC files

# Watch paths
WATCH_DIRS=("/watch/movies" "/watch/tvshows" "/watch/anime")

# Lock and log directories
LOCK_DIR="/watch/.locks"
LOG_DIR="/watch/.logs"
mkdir -p "$LOCK_DIR" "$LOG_DIR"

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Cleanup orphaned temporary files
cleanup_temp_files() {
    log "=== CLEANING UP ORPHANED TEMP FILES ==="
    local count=0
    
    for watch_dir in "${WATCH_DIRS[@]}"; do
        if [ ! -d "$watch_dir" ]; then
            continue
        fi
        
        # Find and remove .tmp.mkv and .orig files
        while IFS= read -r -d '' tmpfile; do
            log "Removing orphaned: $(basename "$tmpfile")"
            rm -f "$tmpfile"
            ((count++))
        done < <(find "$watch_dir" -type f \( -name "*.tmp.mkv" -o -name "*.orig" \) -print0 2>/dev/null)
    done
    
    log "Cleaned up $count orphaned file(s)"
}

# Calculate expected file size in bytes based on resolution and duration
# Returns 0 if file is acceptably sized, 1 if bloated
is_hevc_bloated() {
    local file="$1"
    
    # Get video resolution (height)
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    
    # Get duration in seconds
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    
    # Get file size in bytes
    local filesize=$(stat -c%s "$file" 2>/dev/null)
    
    # Skip if we can't get info
    if [ -z "$height" ] || [ -z "$duration" ] || [ -z "$filesize" ]; then
        return 0
    fi
    
    # Calculate duration in hours
    local hours=$(echo "$duration / 3600" | bc -l)
    
    # Define expected bitrates in kbps for well-encoded HEVC (conservative estimates)
    local expected_bitrate_kbps
    if [ "$height" -ge 2000 ]; then
        # True 4K (2160p): ~8000 kbps (8 Mbps) for well-encoded HEVC
        expected_bitrate_kbps=8000
    elif [ "$height" -ge 1400 ]; then
        # 2K/1440p-1600p range: ~5000 kbps (5 Mbps)
        expected_bitrate_kbps=5000
    elif [ "$height" -ge 1000 ]; then
        # 1080p: ~3000 kbps (3 Mbps)
        expected_bitrate_kbps=3000
    elif [ "$height" -ge 700 ]; then
        # 720p: ~1500 kbps (1.5 Mbps)
        expected_bitrate_kbps=1500
    else
        # SD: ~800 kbps
        expected_bitrate_kbps=800
    fi
    
    # Calculate expected size in bytes (bitrate * duration * 1000 / 8)
    local expected_size=$(echo "$expected_bitrate_kbps * $duration * 1000 / 8" | bc)
    
    # If file is more than 3x the expected size, it's bloated (more lenient threshold)
    local threshold=$(echo "$expected_size * 3" | bc | cut -d. -f1)
    
    if [ "$filesize" -gt "$threshold" ]; then
        local size_gb=$(echo "$filesize / 1073741824" | bc -l | xargs printf "%.1f")
        local expected_gb=$(echo "$expected_size / 1073741824" | bc -l | xargs printf "%.1f")
        log "BLOATED HEVC: $file (${size_gb}GB, expected ~${expected_gb}GB for ${height}p)"
        return 1
    fi
    
    return 0
}

# Check if file should be processed
should_process() {
    local file="$1"
    local ext="${file##*.}"
    
    # Skip if not a video file
    case "${ext,,}" in
        mkv|mp4|avi|mov|m4v|wmv|flv|webm|ts|m2ts) ;;
        *) return 1 ;;
    esac
    
    # Skip partial downloads
    case "$file" in
        *.part|*.!qb|*.tmp|*.download|*.incomplete) return 1 ;;
    esac
    
    # Skip files in downloads folder (for seeding)
    case "$file" in
        */downloads/*) 
            log "SKIP: $file (in downloads folder - likely seeding)"
            return 1 
            ;;
    esac
    
    # Skip if already has a lock file
    local lockfile="$LOCK_DIR/$(basename "$file").lock"
    if [ -f "$lockfile" ]; then
        return 1
    fi
    
    # Check if already HEVC
    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "unknown")
    if [[ "$codec" == "hevc" || "$codec" == "h265" ]]; then
        # If re-encoding bloated HEVC is enabled, check if file is bloated
        if [ "$REENCODE_BLOATED_HEVC" -eq 1 ]; then
            if ! is_hevc_bloated "$file"; then
                log "PROCESS: $file (bloated HEVC - will re-encode)"
                return 0
            fi
        fi
        log "SKIP: $file (already optimized HEVC)"
        return 1
    fi
    
    return 0
}

# Transcode a single file
transcode_one() {
    local input="$1"
    
    # Validate input file exists
    if [ ! -f "$input" ]; then
        log "ERROR: File not found: $input"
        return 1
    fi
    
    local lockfile="$LOCK_DIR/$(basename "$input").lock"
    
    # Create lock
    touch "$lockfile"
    
    log "START: $input"
    
    # Get file info (using proper quoting for special characters)
    local dir="$(dirname "$input")"
    local filename="$(basename "$input")"
    local name="${filename%.*}"
    local temp_output="${dir}/${name}.tmp.${OUTPUT_EXT}"
    local final_output="${dir}/${name}.${OUTPUT_EXT}"
    
    # Run transcode (proper quoting for special characters)
    local ffmpeg_cmd=(
        ffmpeg -y -i "$input"
        -map 0
        -c:v hevc_nvenc -preset "$NV_PRESET" -cq "$NV_CQ"
        -c:a copy -c:s copy
    )
    
    # HDR support
    if [ "$KEEP_HDR" -eq 1 ]; then
        ffmpeg_cmd+=(-profile:v main10 -pix_fmt p010le)
    fi
    
    ffmpeg_cmd+=(-movflags +faststart "$temp_output")
    
    # Run transcode with progress
    log "Transcoding with NVENC (CQ:$NV_CQ, Preset:$NV_PRESET)..."
    if "${ffmpeg_cmd[@]}" 2>&1 | tee -a "$LOG_DIR/transcode.log"; then
        # Check file sizes
        local input_size=$(stat -c%s "$input")
        local output_size=$(stat -c%s "$temp_output")
        
        # Safety check: Output must be at least 100MB (avoid corrupted files)
        if [ "$output_size" -lt 104857600 ]; then
            log "ERROR: Output file too small ($output_size bytes) - likely corrupted!"
            rm -f "$temp_output"
            rm -f "$lockfile"
            return 1
        fi
        
        # Verify output file has valid video stream
        local output_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$temp_output" 2>/dev/null)
        if [ -z "$output_codec" ]; then
            log "ERROR: Output file has no valid video stream - corrupted!"
            rm -f "$temp_output"
            rm -f "$lockfile"
            return 1
        fi
        
        # Verify duration is reasonable (within 5% of original)
        local input_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | cut -d. -f1)
        local output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$temp_output" 2>/dev/null | cut -d. -f1)
        
        if [ -n "$input_duration" ] && [ -n "$output_duration" ]; then
            local duration_diff=$((input_duration - output_duration))
            local duration_diff_abs=${duration_diff#-}  # Absolute value
            local duration_threshold=$((input_duration * 5 / 100))  # 5% threshold
            
            if [ "$duration_diff_abs" -gt "$duration_threshold" ]; then
                log "ERROR: Duration mismatch! Input: ${input_duration}s, Output: ${output_duration}s"
                rm -f "$temp_output"
                rm -f "$lockfile"
                return 1
            fi
        fi
        
        if [ "$output_size" -lt "$input_size" ]; then
            local saved=$((input_size - output_size))
            local percent=$((saved * 100 / input_size))
            log "SUCCESS: $filename - Saved ${percent}% ($saved bytes)"
            
            # Backup original briefly, then replace
            mv "$input" "${input}.orig"
            mv "$temp_output" "$final_output"
            rm -f "${input}.orig"
            
            log "REPLACED: $final_output"
        else
            log "SKIP REPLACE: Output larger than input"
            rm -f "$temp_output"
        fi
    else
        log "ERROR: Transcode failed for $input"
        rm -f "$temp_output"
        rm -f "$lockfile"
        return 1
    fi
    
    # Remove lock
    rm -f "$lockfile"
    return 0
}

# Process all existing files once (with concurrency)
process_existing_once() {
    log "=== INITIAL SCAN: Processing existing files ==="
    log "Concurrent workers: $CONCURRENT_LIMIT"
    
    for watch_dir in "${WATCH_DIRS[@]}"; do
        if [ ! -d "$watch_dir" ]; then
            log "WARN: Directory not found: $watch_dir"
            continue
        fi
        
        log "Scanning: $watch_dir"
        
        # Find all video files and process with parallel jobs
        while IFS= read -r -d '' file; do
            if should_process "$file"; then
                # Run in background with concurrency limit
                while [ $(jobs -r | wc -l) -ge "$CONCURRENT_LIMIT" ]; do
                    sleep 1
                done
                # Use proper quoting and subshell to preserve paths with special chars
                (transcode_one "$file") &
            fi
        done < <(find "$watch_dir" -type f \( \
            -iname "*.mkv" -o \
            -iname "*.mp4" -o \
            -iname "*.avi" -o \
            -iname "*.mov" -o \
            -iname "*.m4v" -o \
            -iname "*.wmv" -o \
            -iname "*.flv" -o \
            -iname "*.webm" -o \
            -iname "*.ts" -o \
            -iname "*.m2ts" \
        \) -print0 2>/dev/null)
        
        # Wait for all background jobs to complete
        wait
    done
    
    log "=== INITIAL SCAN COMPLETE ==="
}

# Watch loop for new files
watch_loop() {
    log "=== STARTING FOLDER WATCH ==="
    
    # Build inotifywait command for all directories
    local watch_paths=()
    for dir in "${WATCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            watch_paths+=("$dir")
            log "Watching: $dir"
        fi
    done
    
    if [ ${#watch_paths[@]} -eq 0 ]; then
        log "ERROR: No valid directories to watch"
        exit 1
    fi
    
    # Watch for file events
    inotifywait -m -r -e close_write,moved_to --format '%w%f' "${watch_paths[@]}" 2>/dev/null | while read -r filepath; do
        # Small delay to ensure file is fully written
        sleep 2
        
        if [ -f "$filepath" ] && should_process "$filepath"; then
            # Process in background with concurrency limit
            while [ $(jobs -r | wc -l) -ge "$CONCURRENT_LIMIT" ]; do
                sleep 1
            done
            (transcode_one "$filepath") &
        fi
    done
}

# Main
main() {
    log "╔═══════════════════════════════════════════════════════════════╗"
    log "║       FFmpeg NVENC Auto-Transcoder (RTX 3080)                ║"
    log "╚═══════════════════════════════════════════════════════════════╝"
    log ""
    log "Configuration:"
    log "  NVENC CQ:             $NV_CQ"
    log "  NVENC Preset:         $NV_PRESET"
    log "  Keep HDR:             $KEEP_HDR"
    log "  Output Format:        $OUTPUT_EXT"
    log "  Concurrent:           $CONCURRENT_LIMIT"
    log "  Re-encode Bloated:    $REENCODE_BLOATED_HEVC"
    log ""
    
    # Check GPU availability
    if ! nvidia-smi &>/dev/null; then
        log "ERROR: NVIDIA GPU not detected!"
        exit 1
    fi
    
    local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader)
    log "GPU Detected: $gpu_name"
    log ""
    
    # Cleanup orphaned temp files from previous runs
    cleanup_temp_files
    log ""
    
    # Process existing files first
    process_existing_once
    
    # Then watch for new files
    watch_loop
}

# Run main
main

