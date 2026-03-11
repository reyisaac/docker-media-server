#!/bin/bash
# Patch vpn-config.ovpn: replace 'remote HOSTNAME port' with 'remote IP port'
# Gluetun only accepts IPs in custom .ovpn. Run this after downloading a new .ovpn from ExpressVPN.
set -e
cd "$(dirname "$0")"
OVPN="${OVPN:-./vpn-config.ovpn}"
if [[ ! -f "$OVPN" ]]; then
  echo "Not found: $OVPN"
  exit 1
fi
LINE=$(grep -E '^\s*remote\s+' "$OVPN" | head -1)
if [[ -z "$LINE" ]]; then
  echo "No 'remote' line in $OVPN"
  exit 1
fi
HOST=$(sed -nE 's/^\s*remote\s+([^[:space:]]+)\s+([0-9]+)\s*$/\1/p' <<< "$LINE")
PORT=$(sed -nE 's/^\s*remote\s+([^[:space:]]+)\s+([0-9]+)\s*$/\2/p' <<< "$LINE")
if [[ -z "$HOST" || -z "$PORT" ]]; then
  echo "Could not parse remote line: $LINE"
  exit 1
fi
# Already an IP?
if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Remote is already an IP. No change."
  exit 0
fi
IP=$(getent hosts "$HOST" 2>/dev/null | awk '{print $1; exit}' || true)
if [[ -z "$IP" ]]; then
  echo "Could not resolve: $HOST"
  exit 1
fi
sed -i "0,/remote ${HOST} ${PORT}/s|remote ${HOST} ${PORT}|remote ${IP} ${PORT}|" "$OVPN"
echo "Patched: remote $HOST $PORT -> remote $IP $PORT"
echo "Restart Gluetun: docker compose restart gluetun"
