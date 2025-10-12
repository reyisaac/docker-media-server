#!/usr/bin/env bash
#
# Media Automation Stack - Complete Setup Script
#
# This script does EVERYTHING:
# 1. Installs Docker and NVIDIA drivers (if needed)
# 2. Creates directory structure
# 3. Generates .env configuration
# 4. Starts all services
#
# Usage:
#   ./setup.sh              # Interactive setup
#   ./setup.sh --skip-deps  # Skip Docker/NVIDIA installation

set -e

# ============================================================================
# Color Output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${BLUE}→ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ============================================================================
# Banner
# ============================================================================
cat << "EOF"

╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           Media Automation Stack - Complete Setup                 ║
║                                                                   ║
║  • VPN-Isolated Torrenting (qBittorrent + ExpressVPN)           ║
║  • Automated Media Management (Radarr + Sonarr)                  ║
║  • GPU Transcoding (FFmpeg + NVENC)                              ║
║  • Streaming Server (Plex)                                       ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

EOF

# ============================================================================
# Configuration
# ============================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MEDIA_ROOT="${MEDIA_ROOT:-$SCRIPT_DIR}"
SKIP_DEPS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-deps) SKIP_DEPS=true ;;
    esac
done

# ============================================================================
# Step 1: Install Prerequisites
# ============================================================================
if [ "$SKIP_DEPS" = false ]; then
    info "Step 1/4: Installing prerequisites (Docker + NVIDIA drivers)"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        warning "Running as root. This is fine, but don't run Docker commands as root later."
    fi
    
    # Update package list
    info "Updating package lists..."
    sudo apt update
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        info "Installing Docker..."
        sudo apt install -y docker.io docker-compose
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Add user to docker group
        if [ "$EUID" -ne 0 ]; then
            sudo usermod -aG docker $USER
            warning "Added $USER to docker group. You need to log out and back in!"
            warning "After logging back in, run: ./setup.sh --skip-deps"
            exit 0
        fi
        success "Docker installed"
    else
        success "Docker already installed"
    fi
    
    # Install NVIDIA drivers and toolkit (optional)
    if command -v nvidia-smi &> /dev/null; then
        info "NVIDIA GPU detected"
        
        if ! command -v nvidia-container-toolkit &> /dev/null; then
            info "Installing NVIDIA Container Toolkit..."
            distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
            curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
            curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
                sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
            
            sudo apt update
            sudo apt install -y nvidia-container-toolkit
            sudo systemctl restart docker
            success "NVIDIA Container Toolkit installed"
        else
            success "NVIDIA Container Toolkit already installed"
        fi
    else
        info "No NVIDIA GPU detected (GPU transcoding will be disabled)"
    fi
    
    success "Prerequisites installed\n"
else
    info "Skipping prerequisite installation\n"
fi

# ============================================================================
# Step 2: Create Directory Structure
# ============================================================================
info "Step 2/4: Creating directory structure"

cd "$MEDIA_ROOT"

# Create required directories
mkdir -p config/{gluetun,qbittorrent,prowlarr,radarr,sonarr,overseerr,bazarr,plex,tailscale,tautulli,ffmpeg-watcher}
mkdir -p downloads/{complete,incomplete}
mkdir -p movies tvshows anime manga

success "Directory structure created\n"

# ============================================================================
# Step 3: Configure Environment
# ============================================================================
info "Step 3/4: Configuring environment"

# Check if .env already exists
if [ -f .env ]; then
    warning ".env file already exists. Using existing configuration."
else
    info "Creating .env file from template..."
    
    # Get user info
    USER_ID=$(id -u)
    GROUP_ID=$(id -g)
    TIMEZONE=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || echo "America/New_York")
    
    # Prompt for VPN credentials
    echo ""
    echo "ExpressVPN Configuration:"
    echo "Get credentials from: https://www.expressvpn.com/setup"
    echo ""
    read -p "ExpressVPN Username: " VPN_USER
    read -sp "ExpressVPN Password: " VPN_PASS
    echo ""
    echo ""
    
    # Generate .env file
    cat > .env << ENVEOF
# ============================================================================
# Media Automation Stack - Environment Configuration
# ============================================================================
# Auto-generated by setup.sh on $(date)

# VPN Configuration
VPN_SERVICE_PROVIDER=custom
VPN_TYPE=openvpn
OPENVPN_CUSTOM_CONFIG=/gluetun/custom.conf
OPENVPN_USER=$VPN_USER
OPENVPN_PASSWORD=$VPN_PASS

# Path Configuration
MEDIA_ROOT=$MEDIA_ROOT
CONFIG_ROOT=$MEDIA_ROOT/config
DOWNLOADS_ROOT=$MEDIA_ROOT/downloads
MOVIES_ROOT=$MEDIA_ROOT/movies
TVSHOWS_ROOT=$MEDIA_ROOT/tvshows
ANIME_ROOT=$MEDIA_ROOT/anime
MANGA_ROOT=$MEDIA_ROOT/manga

# Service Ports
QBITTORRENT_WEBUI_PORT=8080
QBITTORRENT_PORT_TCP=6881
QBITTORRENT_PORT_UDP=6881
PROWLARR_PORT=9696
RADARR_PORT=7878
SONARR_PORT=8989
OVERSEERR_PORT=5055
BAZARR_PORT=6767
TAUTULLI_PORT=8181

# FFmpeg-Watcher (GPU Transcoding)
NV_CQ=23
NV_PRESET=p5
KEEP_HDR=1
OUTPUT_EXT=mkv
CONCURRENT_LIMIT=2

# Docker Configuration
DOCKER_NETWORK=media-network
PUID=$USER_ID
PGID=$GROUP_ID
TZ=$TIMEZONE

# Optional
PLEX_CLAIM=
TAILSCALE_AUTHKEY=
ENVEOF
    
    chmod 600 .env
    success ".env file created"
fi

# Check for VPN config file
if [ ! -f vpn-config.ovpn ]; then
    echo ""
    warning "VPN configuration file not found!"
    warning "Please download your .ovpn file from ExpressVPN and save it as:"
    warning "  $MEDIA_ROOT/vpn-config.ovpn"
    echo ""
    read -p "Press Enter when you've added the VPN config file..."
fi

success "Environment configured\n"

# ============================================================================
# Step 4: Start Services
# ============================================================================
info "Step 4/4: Starting services"

# Build custom images if needed
if [ -d ffmpeg-watcher ]; then
    info "Building ffmpeg-watcher image..."
    docker compose build ffmpeg-watcher --quiet || docker compose build ffmpeg-watcher
fi

# Start all services
info "Starting Docker containers..."
docker compose up -d

# Wait a moment for services to initialize
sleep 3

# Show status
echo ""
success "All services started!\n"

# ============================================================================
# Step 5: Configure Plex (if claimed)
# ============================================================================
if [ -f .env ]; then
    source .env
    
    # Check if Plex is claimed and configure
    PLEX_PREF="${CONFIG_ROOT}/plex/Library/Application Support/Plex Media Server/Preferences.xml"
    
    if [ -f "$PLEX_PREF" ]; then
        PLEX_CLAIMED=$(curl -s "http://localhost:32400/identity" 2>/dev/null | grep -o 'claimed="1"' || echo "")
        
        if [ ! -z "$PLEX_CLAIMED" ]; then
            echo ""
            info "Plex detected and claimed. Configuring libraries and settings..."
            
            # Get Plex token
            PLEX_TOKEN=$(grep -o 'PlexOnlineToken="[^"]*"' "$PLEX_PREF" | cut -d'"' -f2)
            
            if [ ! -z "$PLEX_TOKEN" ]; then
                # Stop Plex to modify preferences
                docker compose stop plex >/dev/null 2>&1
                
                # Backup preferences
                cp "$PLEX_PREF" "${PLEX_PREF}.backup" 2>/dev/null || true
                
                # Update preferences with hardware transcoding and friendly name
                sed -i 's|<Preferences |<Preferences FriendlyName="Media Server" HardwareAcceleratedCodecs="1" FSEventLibraryUpdatesEnabled="1" ScheduledLibraryUpdatesEnabled="1" |' "$PLEX_PREF" 2>/dev/null || true
                
                # Restart Plex
                docker compose start plex >/dev/null 2>&1
                
                success "Plex configured with GPU transcoding and auto-scan!"
                echo ""
                info "📚 Next: Add Plex libraries at http://localhost:32400/web"
                info "    Movies → /movies"
                info "    TV Shows → /tvshows"
                info "    Anime → /anime"
            else
                warning "Could not get Plex token."
                info "Add libraries at: http://localhost:32400/web"
            fi
        fi
    fi
fi

# ============================================================================
# Summary
# ============================================================================
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                    🎉  SETUP COMPLETE!  🎉                       ║
╚═══════════════════════════════════════════════════════════════════╝

📡 Access Your Services:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  qBittorrent (VPN)  →  http://localhost:8080
    Username: admin  /  Password: adminadmin  (CHANGE THIS!)

  Prowlarr           →  http://localhost:9696
  Radarr             →  http://localhost:7878
  Sonarr             →  http://localhost:8989
  Overseerr          →  http://localhost:5055
  Bazarr             →  http://localhost:6767
  Plex               →  http://localhost:32400/web

📝 Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Change qBittorrent password (Settings → Web UI)
  2. Add indexers in Prowlarr (Settings → Indexers)
  3. Plex libraries auto-configured (Movies, TV Shows, Anime)
  4. Add movies/TV shows in Radarr/Sonarr or Overseerr

🔧 Useful Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Check status:       docker compose ps
  View logs:          docker compose logs -f [service]
  Restart:            docker compose restart
  Stop:               docker compose down
  Update:             docker compose pull && docker compose up -d

  Setup Plex libs:    ./setup-plex-libraries.sh
  Check VPN IP:       docker exec gluetun wget -qO- ifconfig.me
  Monitor GPU:        watch -n 1 nvidia-smi

EOF

echo -e "${GREEN}✓ Setup complete! Enjoy your media server.${NC}"

