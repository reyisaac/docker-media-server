#!/bin/bash
# Clean restart for Plex to fix "Address in use" and server unavailable for clients.
# Run from the same directory as docker-compose.yml.

set -e
# Run from scripts directory; CONFIG_ROOT defaults relative to repo root
cd "$(dirname "$0")"
REPO_ROOT="${REPO_ROOT:-$(cd .. && pwd)}"
CONFIG_ROOT="${CONFIG_ROOT:-$REPO_ROOT/config}"

# Prevent native Plex from stealing port 32400 — must stay stopped/disabled/masked
if systemctl is-active --quiet plexmediaserver.service 2>/dev/null; then
  echo "ERROR: Native Plex (plexmediaserver.service) is running and will block Docker Plex."
  echo "Run this first, then try again:"
  echo "  sudo ./plex-fix-conflict.sh"
  echo ""
  exit 1
fi

echo "Stopping Plex..."
docker compose stop plex

# Force IPv4-only so Plex doesn't hit "Address in use" when binding IPv6 (fixes unavailable for clients)
PREFS="${CONFIG_ROOT:-./config}/plex/Library/Application Support/Plex Media Server/Preferences.xml"
if [ -f "$PREFS" ]; then
  if grep -q "IPNetworkType=\"dualstack\"" "$PREFS"; then
    sed -i 's/IPNetworkType="dualstack"/IPNetworkType="ipv4"/' "$PREFS"
    echo "Set Plex to IPv4-only (fixes bind error)."
  fi
fi

echo "Waiting 5s for port 32400 to be released..."
sleep 5

echo "Starting Plex..."
docker compose start plex

echo ""
echo "Wait ~30 seconds, then try your Plex app again."
echo "From this machine: http://localhost:32400/web"
echo "From other devices: http://192.168.0.132:32400/web"
echo ""
echo "If still unavailable: get a new claim token from https://www.plex.tv/claim"
echo "Put it in .env as PLEX_CLAIM=your_token and run: docker compose up -d plex"
