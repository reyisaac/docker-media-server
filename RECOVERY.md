# Media stack – after reboot & when things break

## After a reboot (automatic as possible)

Run once from your media stack root:

```bash
cd /path/to/your/media-stack
./media-stack-after-reboot.sh
```

This script:

- Stops and masks **native Plex** so Docker Plex can use port 32400
- Patches **VPN config** so the `remote` line uses an IP (Gluetun needs this)
- Runs **`docker compose up -d`** so everything starts in order

Give Gluetun 1–2 minutes to become healthy; then qBittorrent will start.

---

## What still has to be done by hand (and when)

| Issue | When | What to do |
|--------|------|------------|
| **Tailscale** not online | Auth key expired or invalid | In [Tailscale Admin → Keys](https://login.tailscale.com/admin/settings/keys), create a new auth key. Put it in `.env` as `TAILSCALE_AUTHKEY=tskey-auth-...`, then `docker compose up -d tailscale`. |
| **Gluetun** unhealthy / **qBittorrent** won’t start | ExpressVPN server changed or .ovpn outdated | Download a new .ovpn from ExpressVPN (Manual config → pick location). Replace `vpn-config.ovpn` with it, then run `./vpn-ovpn-patch.sh` and `docker compose restart gluetun`. |
| **icloudpd** unhealthy | 2FA cookie expired (every few weeks/months) | Run `docker exec -it icloudpd sync-icloud.sh --Initialise` and enter the 2FA code when your device shows it. |

---

## Quick checks

```bash
docker ps -a --format "table {{.Names}}\t{{.Status}}"
```

- **gluetun** should be `(healthy)`.
- **qbittorrent** should be `Up` (and only starts after gluetun is healthy).
- **plex** should be `Up` (native Plex must stay masked).
- **icloudpd** – if `(unhealthy)`, re-run `--Initialise` and 2FA as above.
