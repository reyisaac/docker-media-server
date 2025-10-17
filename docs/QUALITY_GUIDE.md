# Quality Settings Guide

Quick reference for configuring Radarr and Sonarr to download optimal quality releases.

---

## 🎯 Goals

- ✅ Prefer efficient codecs (x265/HEVC over x264/H.264)
- ✅ Prefer quality release groups (Tigole, FLUX, QxR, etc.)
- ✅ Avoid bloated releases (unnecessarily large files)
- ✅ Automatic selection based on scoring

---

## 📥 Radarr Custom Formats

### Quick Import

1. Open **Radarr**: http://localhost:7878
2. **Settings** → Show Advanced (toggle) → **Custom Formats**
3. Click **Import** button (top right)
4. Import each format below:

### Format 1: Prefer x265/HEVC

**File:** `configs/radarr/radarr-custom-format-x265.json`

**Purpose:** Prioritizes x265/HEVC releases (50-70% smaller than x264)

**Score:** `+15` points

### Format 2: Prefer Good Encoders

**File:** `configs/radarr/radarr-custom-format-good-encoders.json`

**Purpose:** Prioritizes releases from trusted encoder groups

**Groups:** FLUX, BYNDR, QxR, PSA, Tigole, Joy, HONE, W4F, NTb, TOMMY, MIXED

**Score:** `+10` points

### Format 3: Avoid Bloated Releases

**File:** `configs/radarr/radarr-custom-format-avoid-bloated.json`

**Purpose:** Penalizes unnecessarily large 1080p releases (>50GB)

**Score:** `-100` points

---

## ⚙️ Assign to Quality Profile

After importing all formats:

1. **Settings** → **Profiles**
2. Click your profile (e.g., "HD-1080p" or "Any")
3. Go to **Custom Formats** tab
4. Set these scores:
   - **x265/HEVC Preferred:** `+15`
   - **Good Encoders:** `+10`
   - **Bloated Releases:** `-100`
5. Set **Minimum Custom Format Score:** `0`
6. Click **Save**

---

## ✅ Verify It's Working

1. **Movies** → **Add New Movie**
2. Search for any movie
3. Click **Manual Search** (magnifying glass icon)
4. Check release scores:
   - ✅ Releases with x265/HEVC: **+15 points**
   - ✅ Releases from good groups: **+10 points**
   - ❌ Bloated releases (>50GB for 1080p): **-100 points**
5. Top-scored release will be auto-selected! ✅

---

## 📺 Sonarr Custom Formats

Same process as Radarr, but adjust the "Bloated Releases" size limits for TV episodes:

1. Open **Sonarr**: http://localhost:8989
2. Import the same 3 custom formats
3. Modify **Bloated Releases** for TV episodes:
   - **1080p episodes:** Avoid files > **5GB per episode**
   - **4K episodes:** Avoid files > **15GB per episode**

---

## 🎬 Expected Results

**Before:**
- Downloads 58GB Blu-ray Remux (bloated)
- Downloads x264 releases (inefficient)
- No preference for quality groups

**After:**
- Prefers 8-12GB x265 releases (efficient)
- Prefers trusted encoders (Tigole, FLUX, etc.)
- Avoids bloated files (>50GB for 1080p)
- Automatic optimal selection! ✅

---

## 💡 Tips

**Ideal File Sizes:**
- **1080p:** 2-8 GB (x265) or 4-12 GB (x264)
- **4K/2160p:** 8-25 GB (x265) or 20-50 GB (x264)

**Quality Groups to Trust:**
- **Tigole**: Excellent x265 encodes, HDR support
- **FLUX**: High-quality scene releases
- **QxR**: Balanced size/quality
- **Joy**: Premium anime/movie encodes

**Avoid:**
- YTS/YIFY (too compressed, poor quality)
- Unknown/untrusted encoders
- Extremely small files (micro-encodes)
- Remux files (unless you want uncompressed)

---

**See Also:**
- [Detailed Setup Instructions](SETUP_INSTRUCTIONS.md)
- [README](../README.md)
