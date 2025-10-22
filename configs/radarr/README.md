# Radarr Configuration - Clean Setup

## 📁 **Files Overview**

### **Custom Formats (Import Order):**
1. `01-old-movies-4k-under-15gb.json` - 4K under 15GB for old movies (1990-2013)
2. `02-old-movies-1080p-fallback.json` - 1080p under 8GB for old movies
3. `03-modern-movies-4k-under-30gb.json` - 4K under 30GB for modern movies (2014+)
4. `04-avoid-large-4k-old-movies.json` - Penalty for large 4K old movies
5. `05-x265-hevc-preferred.json` - x265 encoding bonus
6. `06-good-encoders.json` - Quality release groups bonus
7. `07-high-peer-count.json` - High peer count bonus

### **Quality Profiles:**
8. `08-quality-profile-old-movies.json` - Old Movies Space Efficient (1080p max)
9. `09-quality-profile-modern-movies.json` - Modern Movies High Quality (4K allowed)

## ⚙️ **Setup Instructions**

### **Step 1: Import Custom Formats**
1. Go to Radarr → Settings → Custom Formats
2. Import files 01-07 in order
3. Set these scores:

#### **For Old Movies Profile:**
- Old Movies 4K Under 15GB: **+40**
- Old Movies 1080p Fallback: **+30**
- Avoid Large 4K Old Movies: **-50**
- x265/HEVC Preferred: **+15**
- Good Encoders: **+10**
- High Peer Count: **+15**

#### **For Modern Movies Profile:**
- Modern Movies 4K Under 30GB: **+35**
- x265/HEVC Preferred: **+15**
- Good Encoders: **+10**
- High Peer Count: **+15**

### **Step 2: Create Quality Profiles**
1. Go to Settings → Quality Profiles
2. Import `08-quality-profile-old-movies.json`
3. Import `09-quality-profile-modern-movies.json`

### **Step 3: Apply Profiles**
- **Movies 1990-2013**: Use "Old Movies Space Efficient"
- **Movies 2014+**: Use "Modern Movies High Quality"

## 🎯 **Expected Results**

### **Old Movies (1990-2013):**
- **Alien³ (1992)**: 6.4GB 4K or 2.1GB 1080p (not 40GB)
- **X-Men (2000)**: 2.2GB 1080p or 5.3GB 4K (not 23.7GB)
- **Space Savings**: 50-70% reduction

### **Modern Movies (2014+):**
- **Avengers Endgame (2019)**: 4K under 30GB
- **Dune (2021)**: 4K under 30GB
- **Quality Maintained**: High quality with reasonable size limits

## 📊 **Scoring Summary**

| Format | Old Movies | Modern Movies |
|--------|------------|---------------|
| 4K Under 15GB | +40 | +35 |
| 1080p Under 8GB | +30 | +20 |
| x265 Encoding | +15 | +15 |
| Good Encoders | +10 | +10 |
| High Peers | +15 | +15 |
| Large 4K Penalty | -50 | -30 |

This clean setup gives you optimal space efficiency for old movies while maintaining high quality for modern movies!
