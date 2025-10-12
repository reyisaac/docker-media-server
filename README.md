# Media Automation Stack

**Automated Docker-based media server with VPN-isolated torrenting, GPU transcoding, and intelligent download management for Linux.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU%20Accelerated-green.svg)](https://developer.nvidia.com/cuda-zone)

---

## 🚀 Quick Start

Get your media automation stack running in **3 steps** (~15 minutes):

### Step 1: Download VPN Config

1. Go to https://www.expressvpn.com/setup
2. Download your `.ovpn` configuration file
3. Save it as `vpn-config.ovpn` in this directory

### Step 2: Run Setup

```bash
./setup.sh
```

The script will:
- ✓ Install Docker & NVIDIA drivers (if needed)
- ✓ Prompt for your ExpressVPN credentials
- ✓ Create directory structure
- ✓ Generate configuration
- ✓ Start all services

### Step 3: Configure Plex (One-Time Setup)

1. Get claim token from https://www.plex.tv/claim/
2. Add to `.env`: `PLEX_CLAIM=claim-XXXX`
3. Run: `docker compose up -d plex && sleep 10 && ./setup.sh --skip-deps`
4. Open http://localhost:32400/web
5. Click **"+ Add Library"** and add:
   - **Movies** → `/movies` (16 movies ready)
   - **TV Shows** → `/tvshows`
   - **Anime** → `/anime`

**Done!** GPU transcoding and auto-scan are already configured.

### Step 4: Configure Other Services

1. **Change qBittorrent password** → http://localhost:8080 (default: admin/adminadmin)
2. **Add indexers to Prowlarr** → http://localhost:9696

**Done!** Start adding movies and TV shows via Radarr/Sonarr or Overseerr.

---

## 📋 Overview

Self-hosted media automation with:
- 🔒 **VPN-Isolated Torrenting** - Only qBittorrent routes through ExpressVPN
- 🤖 **Automated Management** - Radarr (movies), Sonarr (TV), Prowlarr (indexers)
- ⚡ **GPU Transcoding** - FFmpeg with NVENC (4K → 8GB in 30 min)
- 🎬 **Media Serving** - Plex, Overseerr, Bazarr
- 🧹 **Auto Cleanup** - Removes downloads after 24h seeding
- 🛡️ **Kill-Switch** - If VPN drops, qBittorrent has no internet

---

## 📦 Prerequisites

- Pop!_OS 22.04+ or Ubuntu-based Linux
- Docker and Docker Compose (auto-installed by setup script)
- ExpressVPN account
- NVIDIA GPU (optional, for hardware transcoding)

---

## 🔧 Services

| Service | Port | Purpose | VPN |
|---------|------|---------|-----|
| qBittorrent | 8080 | Torrent client | ✓ ExpressVPN |
| Prowlarr | 9696 | Indexer manager | ✗ LAN |
| Radarr | 7878 | Movie automation | ✗ LAN |
| Sonarr | 8989 | TV automation | ✗ LAN |
| Overseerr | 5055 | Request management | ✗ LAN |
| Bazarr | 6767 | Subtitle automation | ✗ LAN |
| Plex | 32400 | Media server | ✗ LAN |
| FFmpeg-Watcher | - | GPU transcoding | ✗ LAN |

**Default Credentials:**
- qBittorrent: `admin` / `adminadmin` ⚠️ Change immediately!
- Others: Set up on first visit

---

## 🏗️ Architecture

```
Internet
    ↓
ExpressVPN (Gluetun)
    ↓
qBittorrent (VPN only)
    │
    │
Local Network
    ↓
Prowlarr ↔ Radarr/Sonarr
    ↓           ↓
Indexers   Downloads → Auto Cleanup (24h)
               ↓
         Media Folders
               ↓
        FFmpeg-Watcher (GPU transcode)
               ↓
             Plex
```

**Key Features:**
- Only qBittorrent uses VPN (`network_mode: service:gluetun`)
- Other services use direct LAN access
- VPN kill-switch: If VPN drops, qBittorrent loses all connectivity
- Downloads auto-cleaned after 24h seeding

---

## 📂 Directory Structure

```
media-automation-stack/
├── config/              # Service configurations (auto-generated)
├── downloads/           # Torrent downloads (auto-cleanup after 24h)
│   ├── complete/
│   └── incomplete/
├── movies/              # Movie library
├── tvshows/             # TV library
├── anime/               # Anime library
├── manga/               # Manga library
├── ffmpeg-watcher/      # Transcoding scripts
├── .env                 # Your configuration (create from env.example)
├── env.example          # Configuration template
├── setup.sh             # One-command setup
├── docker-compose.yml   # Container definitions
└── vpn-config.ovpn     # Your VPN config
```

---

## ⚙️ Configuration

The `setup.sh` script creates `.env` automatically, but you can customize it:

```env
# VPN Credentials
OPENVPN_USER=your_username
OPENVPN_PASSWORD=your_password

# GPU Transcoding Settings
NV_CQ=23              # Quality: 18-28 (lower=better, 23 is balanced)
NV_PRESET=p5          # Speed: p1-p7 (higher=slower/better)
KEEP_HDR=1            # Preserve HDR metadata
CONCURRENT_LIMIT=2    # Concurrent transcodes (2 optimal for RTX 3080)

# Paths (auto-configured)
MEDIA_ROOT=/path/to/your/media-stack
MOVIES_ROOT=/path/to/your/media-stack/movies
# ...
```

---

## 📺 Using the Stack

### Add Content via Overseerr (Easiest)

1. Open http://localhost:5055
2. Connect to Plex, Radarr, and Sonarr
3. Search and request movies/TV shows
4. They download automatically!

### Add Content Directly

**Movies (Radarr):**
```
http://localhost:7878 → Search → Add Movie → Auto-downloads
```

**TV Shows (Sonarr):**
```
http://localhost:8989 → Search → Add Series → Auto-downloads episodes
```

**Workflow:**
1. Search in Radarr/Sonarr
2. Prowlarr searches indexers
3. qBittorrent downloads via VPN
4. Radarr/Sonarr imports to media folder
5. FFmpeg-Watcher transcodes (GPU)
6. Plex makes available for streaming
7. After 24h seeding, auto-cleanup removes download

---

## 🎮 Common Commands

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f qbittorrent
docker compose logs -f radarr
docker compose logs -f ffmpeg-watcher

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start (after stopping)
docker compose up -d

# Update all services
docker compose pull
docker compose up -d

# Check VPN IP (should show ExpressVPN server)
docker exec gluetun wget -qO- ifconfig.me

# Monitor GPU transcoding
watch -n 1 nvidia-smi

# Manual cleanup test
docker exec download-cleanup /usr/local/bin/cleanup-downloads.sh
```

---

## 🐛 Troubleshooting

### VPN Not Connecting

```bash
docker compose logs -f gluetun
# Check credentials in .env file
nano .env
docker compose restart gluetun
```

### GPU Not Working

```bash
# Check GPU detection
nvidia-smi

# Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Reinstall NVIDIA drivers
sudo ubuntu-drivers autoinstall
sudo reboot
```

### Permission Denied (Docker)

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :8080

# Change port in .env
nano .env
docker compose restart
```

### Check Service Health

```bash
# Validate everything
docker compose ps
docker exec gluetun wget -qO- ifconfig.me  # Should be VPN IP
curl ifconfig.me  # Should be your home IP (different!)
```

---

## 🔐 Security

- ⚠️ **Change qBittorrent password immediately** (Settings → Web UI)
- 🔒 Set authentication on all services (Prowlarr, Radarr, Sonarr)
- 📝 Keep `.env` file private (`chmod 600 .env`)
- 🛡️ VPN kill-switch is automatic (qBittorrent isolated)
- 🏠 Only expose ports on local network (don't forward publicly)
- 🌐 Consider Tailscale for secure remote access

---

## 🎯 Advanced Features

### GPU Transcoding

FFmpeg-Watcher monitors media folders and automatically transcodes:
- **4K movies:** 40-60GB → 8-10GB (80% smaller) in 30-40 min
- **1080p movies:** 10-20GB → 3-6GB in 5-10 min
- Keeps all audio tracks, subtitles, and chapters
- Preserves HDR/4K quality
- Only replaces if new file is smaller
- Optimized for RTX 3080 (2 concurrent streams)

### Automatic Download Cleanup

Runs every 6 hours, removes downloads older than 24h:
- Checks for active downloads (skips .!qb, .part files)
- Logs all actions
- Shows space freed

Customize in `docker-compose.yml`:
```yaml
# Change schedule (default: every 6 hours at 0:00, 6:00, 12:00, 18:00)
echo '0 3 * * * /usr/local/bin/cleanup-downloads.sh ...' 
```

---

## 📊 How It Works

### Media Workflow

1. **Request** → Search in Radarr/Sonarr/Overseerr
2. **Search** → Prowlarr searches configured indexers
3. **Download** → qBittorrent downloads via VPN
4. **Seed** → qBittorrent seeds for 24 hours
5. **Import** → Radarr/Sonarr move file to media folder (hardlink)
6. **Transcode** → FFmpeg-Watcher optimizes with GPU
7. **Serve** → Plex makes available for streaming
8. **Cleanup** → After 24h, download removed automatically

### VPN Isolation

- qBittorrent shares Gluetun's network stack
- If VPN drops, qBittorrent has **zero** internet access
- All other services bypass VPN for direct LAN access
- Radarr/Sonarr communicate with qBittorrent via Docker network

---

## 🔄 Updates

```bash
# Update all Docker images
docker compose pull
docker compose up -d

# Rebuild custom images (ffmpeg-watcher)
docker compose build ffmpeg-watcher
docker compose up -d ffmpeg-watcher
```

---

## 💾 Backup

**Important files to backup:**
```bash
# Backup configs and credentials
tar -czf media-backup-$(date +%Y%m%d).tar.gz .env config/

# Restore
tar -xzf media-backup-20250101.tar.gz
```

Optionally backup media files (movies, tvshows, etc.)

---

## 🤝 Contributing

Contributions welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important:** This software is for personal use only. Users are responsible for complying with all applicable laws and terms of service.

---

## 🙏 Acknowledgments

- Built with Docker containers from [LinuxServer.io](https://www.linuxserver.io/)
- VPN routing powered by [Gluetun](https://github.com/qdm12/gluetun)
- Transcoding powered by [FFmpeg](https://ffmpeg.org/) with NVIDIA NVENC
- Media management by [Radarr](https://radarr.video/), [Sonarr](https://sonarr.tv/), and [Prowlarr](https://prowlarr.com/)

---

**Version:** 2.0 (Linux Edition)  
**Last Updated:** October 2025

🎬 **Enjoy your automated media server!**
