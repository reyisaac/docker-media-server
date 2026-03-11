#!/bin/bash
# Run after a reboot/update to get the media stack back with minimal manual steps.
# Usage: ./media-stack-after-reboot.sh   (sudo only needed for masking native Plex)
set -e
cd "$(dirname "$0")"

echo "=== Media stack post-reboot ==="
echo ""

# 1) Ensure native Plex doesn't steal port 32400 (one-time; harmless to run again)
if systemctl is-active --quiet plexmediaserver.service 2>/dev/null; then
  echo "Stopping and masking native Plex so Docker Plex can bind..."
  sudo systemctl stop plexmediaserver.service 2>/dev/null || true
  sudo systemctl disable plexmediaserver.service 2>/dev/null || true
  sudo systemctl mask plexmediaserver.service 2>/dev/null || true
  echo "  Done."
elif ! systemctl is-enabled plexmediaserver.service 2>/dev/null; then
  echo "Native Plex already disabled/masked. OK."
fi
echo ""

# 2) If .ovpn has a hostname in 'remote', resolve to IP (Gluetun requires IP)
if grep -qE '^\s*remote\s+[a-zA-Z0-9.-]+\s+[0-9]+' ./vpn-config.ovpn 2>/dev/null; then
  echo "Patching VPN config (hostname -> IP)..."
  ./vpn-ovpn-patch.sh || true
else
  echo "VPN config remote already an IP or not found. Skipping patch."
fi
echo ""

# 3) Start everything (compose will wait for gluetun healthy then start qbittorrent)
echo "Starting Docker stack..."
docker compose up -d
echo ""

# 4) Short status
echo "Status (give Gluetun ~1–2 min to become healthy):"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -20
echo ""
echo "If Tailscale or icloudpd stay down/unhealthy, see RECOVERY.md."
