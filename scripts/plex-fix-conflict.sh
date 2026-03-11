#!/bin/bash
# Stop native Plex (systemd) so Docker Plex can use port 32400.
# Run with: sudo ./plex-fix-conflict.sh

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Run with sudo: sudo $0"
   exit 1
fi

echo "Stopping native Plex (plexmediaserver.service)..."
systemctl stop plexmediaserver.service 2>/dev/null || true

echo "Disabling native Plex so it won't start on boot..."
systemctl disable plexmediaserver.service 2>/dev/null || true

echo "Masking native Plex so it can't be started by mistake..."
systemctl mask plexmediaserver.service 2>/dev/null || true

echo "Done. Native Plex is stopped, disabled, and masked."
echo ""
echo "Now restart Docker Plex from your media stack root:"
echo "  cd /path/to/your/media-stack && docker compose restart plex"
echo ""
echo "Wait ~30 seconds, then open your Plex app — it should see Reynaldo's Family."
echo ""
echo "To use native Plex again later: sudo systemctl unmask plexmediaserver && sudo systemctl enable --now plexmediaserver"
