# Media Server Setup Instructions - SIMPLE APPROACH

## Strategy: Let Tdarr Transcode Everything

This simpler approach:
- ✅ Radarr/Sonarr download anything (no quality filtering)
- ✅ Tdarr re-encodes ALL files to consistent quality/size
- ✅ Target bitrates prevent bloat automatically
- ✅ Less UI configuration needed!

---

## 🎬 RADARR CONFIGURATION (OPTIONAL - 2 minutes)

Radarr will work fine with defaults. Only set this if you want basic size limits:

### Quick Setup (Optional):
1. Open: **http://localhost:7878**
2. Go to **Settings** → **Show Advanced** → **Profiles**
3. Edit **HD-1080p** profile
4. Set basic max limits (optional):
   - **1080p**: Max 50GB (very generous, catches only extreme bloat)
   - **2160p**: Max 100GB (very generous)
5. Click **Save**

**That's it for Radarr!** Tdarr will handle quality control.

---

## 📺 SONARR CONFIGURATION (OPTIONAL - 2 minutes)

Same as Radarr - defaults are fine. Optional basic limits:

### Quick Setup (Optional):
1. Open: **http://localhost:8989**
2. Go to **Settings** → **Show Advanced** → **Profiles**
3. Edit **HD-1080p** profile
4. Set basic max limits per episode (optional):
   - **1080p**: Max 5GB per episode (very generous)
   - **2160p**: Max 15GB per episode (very generous)
5. Click **Save**

**That's it for Sonarr!** Tdarr will handle quality control.

---

## 🎞️ TDARR CONFIGURATION (10-15 minutes) - MAIN SETUP

This is where the magic happens! Tdarr will transcode ALL files.

### Step 1: Access Tdarr
Open: **http://localhost:8265**

### Step 2: Create Libraries

Click **Libraries** tab → **Library +** button

**Library 1: Movies**
```
Name: Movies
Source: /media/movies
Cache: /media/movies
Output: /media/movies
```
Click **Save**

**Library 2: TV Shows**
```
Name: TV Shows
Source: /media/tvshows
Cache: /media/tvshows
Output: /media/tvshows
```
Click **Save**

**Library 3: Downloads** (Optional - for pre-import transcoding on SSD)
```
Name: Downloads
Source: /media/downloads
Cache: /media/downloads
Output: /media/downloads
```
Click **Save**

---

### Step 3: Configure "Transcode Everything" Flow

For **each library** you created:

1. Click on the library name
2. Go to **Transcode Options** tab
3. Switch to **Flows** mode (toggle at top)
4. Click **+ Create Flow**

**Build this Flow to transcode ALL files:**

#### Node 1: Input (already there)

#### Node 2: Check if video exists
- Plugin: **Input File**
- Just confirms it's a video file

#### Node 3: Check Bitrate (decides if transcode needed)
- Plugin: **Check Bitrate**
- This checks if file is bloated
- Settings:
  - **If bitrate over these limits, transcode:**
    - **1080p**: 12000 kbps (12 Mbps) - good quality threshold
    - **2160p**: 35000 kbps (35 Mbps) - good quality threshold
    - **720p**: 6000 kbps (6 Mbps)
  - Action if OVER: Continue to transcode
  - Action if UNDER: Still continue (we want to force transcode everything)

**Alternative: Skip Node 3 entirely to transcode EVERYTHING regardless of current quality**

#### Node 4: Transcode Video (THE KEY NODE)
- Plugin: **Transcode Video - Custom**
- Settings:
  
  **Video Codec:**
  - Encoder: `hevc_nvenc` (GPU encoding)
  - Preset: `p4` (balanced) or `p5` (more quality)
  - CQ (Quality): `23` (lower = better quality, 23 is good)
  
  **Target Bitrates (prevents bloat):**
  - **2160p (4K)**: 
    - Target: 20000 kbps (20 Mbps)
    - Max: 35000 kbps (35 Mbps)
  - **1080p**: 
    - Target: 8000 kbps (8 Mbps)
    - Max: 12000 kbps (12 Mbps)
  - **720p**: 
    - Target: 4000 kbps (4 Mbps)
    - Max: 6000 kbps (6 Mbps)
  
  **Container:**
  - Output: `mkv`
  
  **Audio:**
  - Keep all audio streams
  - Copy audio (don't transcode audio)
  
  **Subtitles:**
  - Keep all subtitle streams
  
  **Advanced:**
  - ✅ Force Transcode: YES (transcode even if already HEVC)
  - ✅ Replace Original: YES (overwrite the source file)

#### Node 5: Output (add at end)

5. Click **Save Flow**

---

### Step 3b: OR Use Community Flow (Easier!)

Instead of building manually:

1. Search community flows for: **"Migz-Transcode using Nvidia GPU"**
2. Click **Install**
3. **Edit the flow:**
   - Find any "Skip if HEVC" condition node
   - **DELETE IT** (we want to transcode HEVC too)
   - Make sure "Force Transcode" is enabled
   - Set target bitrates as above
4. Click **Save**

---

### Step 4: Configure Worker Settings

1. Go to **Options** tab (top menu)
2. Go to **Transcode** section
3. Set:
   - **GPU Workers**: 2 (or more if you have a powerful GPU)
   - **CPU Workers**: 0 (we're using GPU only)
   - **Health Check Workers**: 1

4. Click **Save**

---

### Step 5: Start Library Scans

1. Go back to **Libraries** tab
2. For each library:
   - Click **Scan** button
   - Tdarr will index all files
   - Files will queue for transcoding in **Staging** tab

---

## ✅ VERIFICATION CHECKLIST

### 1. Check Tdarr is Working

Open Tdarr: http://localhost:8265

**Check Staging Tab:**
- Should show files queued for transcoding
- Status: "Queued" or "Processing"

**Check Workers Tab:**
- Should show GPU workers active
- "MainNode" should be online with 2 GPU workers

**Monitor GPU:**
Open terminal and run:
```bash
watch -n 2 nvidia-smi
```
- GPU usage should spike when transcoding
- Video encoder (NVENC) should show activity

### 2. Check a Transcode

1. Go to **Staging** tab
2. Find a file being processed
3. Click on it to see details
4. Check:
   - Input codec (might be h264 or hevc)
   - Output codec (should be hevc_nvenc)
   - Target bitrate being applied
   - Transcode progress

### 3. Test Download Workflow

1. Add a movie in **Overseerr** or **Radarr**
2. Watch it download to: `/media/isaacreynaldo/Storage/media/downloads` (SSD)
3. Check **qBittorrent** - should be seeding from SSD
4. After Radarr imports to library (HDD), Tdarr will process it
5. Check final file size is reasonable (not bloated)

### 4. Verify Disk Usage

Check space regularly:
```bash
df -h /media/isaacreynaldo/Storage     # 1TB SSD
df -h /media/isaacreynaldo/media8tb     # 8TB HDD
```

Expected:
- Downloads folder grows on SSD
- Library folder grows on HDD with processed files
- Processed files should be smaller than originals if they were bloated

---

## 🎯 EXPECTED RESULTS

With this "transcode everything" setup:

✅ **All files re-encoded to consistent quality**
- Even HEVC files get re-encoded if bloated
- Target bitrates ensure no bloat

✅ **Automatic quality control**
- 2160p (4K): ~15-25GB per movie (efficient)
- 1080p: ~6-10GB per movie (efficient)
- 720p: ~3-5GB per movie (efficient)

⚠️ **More transcoding work**
- Tdarr will transcode 100% of files
- Takes longer, but ensures consistency
- Good for libraries with many bloated files

✅ **No manual quality management needed**
- Just download and let Tdarr handle it
- Set it and forget it!

---

## 📊 MONITORING

### Check Tdarr Progress
```
Tdarr UI → Statistics → Processing Stats
```
Shows:
- Total files processed
- Space saved
- Processing queue

### Monitor Active Transcodes
```
Tdarr UI → Staging → Filter: Processing
```
Shows real-time progress with:
- Current frame
- FPS (frames per second)
- ETA
- Output size

### Check GPU Usage
```bash
watch -n 2 nvidia-smi
```
Shows:
- GPU utilization %
- NVENC encoder usage
- Memory usage
- Temperature

### Check Disk Space
```bash
watch -n 60 'df -h | grep /media/isaacreynaldo'
```
Monitors both SSD and HDD usage over time.

---

## 🆘 TROUBLESHOOTING

### Tdarr Not Transcoding Files

**Check 1: Workers Active?**
- Tdarr UI → Workers tab
- Should show "MainNode" with 2 GPU workers
- Status should be "Idle" (waiting) or "Processing"

**Check 2: Files in Queue?**
- Tdarr UI → Staging tab
- Should show files with status "Queued"
- If empty, click "Scan" in Libraries

**Check 3: GPU Available?**
```bash
docker exec -it tdarr nvidia-smi
```
- Should show GPU info
- If error, GPU passthrough not working

**Check 4: Transcode Cache Space?**
```bash
df -h /media/isaacreynaldo/Storage/media/config/tdarr/transcode_cache
```
- Needs free space for temp files

### Transcodes Failing

**Check Logs:**
```bash
docker logs tdarr
```

**Common issues:**
- Out of disk space
- Corrupt source file
- Unsupported codec (rare)

**Fix:**
- Free up space
- Skip bad file in Tdarr UI
- Update FFmpeg (restart Tdarr container)

### Transcodes Too Slow

**Current speed:**
- 1080p: ~1 hour per movie (GPU)
- 4K: ~2-3 hours per movie (GPU)

**If slower:**
- Check GPU usage with `nvidia-smi`
- Reduce worker count if GPU overheating
- Check preset (p4 is balanced, p1 is fastest but lower quality)

### Files Not Being Processed

**Check Flow Configuration:**
- Tdarr UI → Library → Transcode Options → Flows
- Verify flow is enabled
- Check flow logic doesn't have "skip" conditions

**Force Scan:**
- Tdarr UI → Libraries → Click "Scan" button
- Wait 1-2 minutes for scan to complete

---

## 🔧 ADVANCED TUNING

### Adjust Quality vs Size

In your Tdarr Flow, modify the transcode node:

**Higher Quality (larger files):**
- CQ: 20-21 (instead of 23)
- Target bitrate: +30%

**Smaller Files (slight quality loss):**
- CQ: 25-26 (instead of 23)
- Target bitrate: -30%

### Adjust Speed vs Quality

Modify NVENC preset in transcode node:

**Faster (lower quality):**
- Preset: `p1` or `p2` (2-3x faster)

**Better Quality (slower):**
- Preset: `p6` or `p7` (1.5x slower)

**Balanced (recommended):**
- Preset: `p4` or `p5` (current)

### Batch Process by Priority

Create multiple flows for different libraries:

**High Priority (Movies):**
- More GPU workers
- Higher quality settings

**Low Priority (TV Shows):**
- Fewer GPU workers
- Faster presets

---

## 📁 FILE SIZE TARGETS

After Tdarr processing, expect these sizes:

**Movies:**
- 720p: 1-3 GB
- 1080p: 4-10 GB
- 4K: 12-25 GB

**TV Episodes (45 min):**
- 720p: 300-600 MB
- 1080p: 800-2000 MB
- 4K: 2-5 GB

Files larger than these targets should be rare (only high-action scenes).

---

## 🎯 WORKFLOW SUMMARY

Your final automated workflow:

```
1. Request movie/show
   ↓
2. Radarr/Sonarr searches
   ↓
3. Downloads to SSD (any quality/size)
   ↓
4. Import to HDD library
   ↓
5. Tdarr scans library
   ↓
6. Tdarr transcodes to HEVC (target bitrate)
   ↓
7. Replaces file with optimized version
   ↓
8. Plex streams optimized file
```

**Result:** Consistent quality, no bloat, fully automated!

---

## 💡 NOTES

### Why This Approach?

✅ **Simplest setup** - no complex Radarr/Sonarr filters
✅ **Guaranteed quality** - every file processed to spec
✅ **Fixes bloated files** - re-encodes to target bitrate
✅ **Future-proof** - works with any download source

### Generation Loss Warning

⚠️ Re-encoding HEVC → HEVC causes slight quality loss (generation loss)

**When acceptable:**
- Source is bloated (60GB+ for 1080p)
- Source is poor quality encode
- Consistency more important than absolute quality

**When to avoid:**
- High-quality source already at target bitrate
- Source is pristine Blu-ray remux you want to keep

**Solution:** Set bitrate check threshold higher (Node 3) to skip good encodes.

---

**Configuration complete! Tdarr will now process all your media to consistent quality.** 🚀
