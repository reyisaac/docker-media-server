# Running on Windows & macOS

This stack is developed and best-supported on **Linux**, but the Compose file itself is
portable — every host path is an `${...}` environment variable, so the services run
anywhere Docker does. The parts that **don't** transfer automatically are **GPU hardware
transcoding**, **file-path formats**, and Linux-only **PUID/PGID** permissions. This guide
covers each.

> **TL;DR**
> - **Linux + NVIDIA** → works as documented, no changes.
> - **Windows** → Docker Desktop + WSL2. GPU works via the WSL2 NVIDIA Container Toolkit. Use forward-slash / drive-letter paths.
> - **macOS** → runs, but **no GPU passthrough exists** (Apple Silicon or Intel). Run GPU-less: Tdarr on CPU and Plex software transcoding.

---

## 1. File paths (`.env`)

Copy `env.example` to `.env` and set the `*_ROOT` variables for your OS. Docker Desktop
accepts **forward slashes** on every platform.

| Platform | Example `MOVIES_ROOT` |
|---|---|
| Linux | `/mnt/media/movies` |
| Windows (Docker Desktop) | `D:/media/movies` |
| Windows (WSL2 filesystem — faster) | `/home/you/media/movies` (run compose from inside WSL2) |
| macOS | `/Users/you/media/movies` |

**Windows tip:** storing media on the **WSL2 filesystem** (`\\wsl$\...`) is much faster than
bind-mounting a Windows drive (`C:`/`D:`) into containers. If you keep media on a Windows
drive, make sure the drive is shared in **Docker Desktop → Settings → Resources → File Sharing**.

---

## 2. PUID / PGID (Linux permissions)

The LinuxServer.io images use `PUID`/`PGID` to match file ownership to your Linux user
(`id -u` / `id -g`). On **Docker Desktop (Windows/macOS)** this mapping is handled by the VM
and the values are effectively ignored — **leave the defaults (`1000`)**. On native Linux,
set them to your user's IDs to avoid permission problems.

---

## 3. GPU / hardware transcoding — the big one

Tdarr's GPU nodes and Plex hardware transcoding assume an **NVIDIA GPU + the NVIDIA
Container Toolkit**. Here's how that maps per platform.

### Linux + NVIDIA (default)
Works as-is. Requires the host NVIDIA driver + `nvidia-container-toolkit`.

### Windows + NVIDIA (via WSL2)
1. Install **Docker Desktop** with the **WSL2 backend**.
2. Install a recent **NVIDIA driver on Windows** (WSL CUDA support is built in — do *not*
   install a driver inside WSL).
3. Install the **NVIDIA Container Toolkit inside your WSL2 distro**
   ([guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)).
4. Verify: `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`
5. Run the stack **from inside WSL2** (not PowerShell) for best results.

### macOS — no GPU passthrough
Docker Desktop on macOS **cannot** pass through any GPU (Apple Silicon or Intel). You must
run **GPU-less** (see below). Plex will software-transcode (uses CPU); Tdarr can transcode on
CPU but it's slow.

### Linux with AMD/Intel GPU (VAAPI)
NVENC won't work. Use **VAAPI** via `/dev/dri` instead — replace the NVIDIA `deploy`/`runtime`
GPU config with a device mount `- /dev/dri:/dev/dri` and use `hevc_vaapi` in Tdarr / set Plex
to your iGPU. (See the Tdarr and Plex docs for VAAPI specifics.)

### Running GPU-less (macOS, or any host without a supported GPU)
The GPU is only used by **Tdarr's worker nodes** and **Plex hardware transcoding** — every
other service is CPU-only and runs unchanged. To run without a GPU:

1. In `docker-compose.yml`, remove (or comment out) the **NVIDIA `runtime` / `deploy.resources.reservations.devices`**
   blocks on the `tdarr-node-*` and `plex` services, and the extra `tdarr-node-*` GPU worker
   services if present.
2. In **Plex → Settings → Transcoder**, leave "Use hardware acceleration when available"
   **off** (it will software-transcode).
3. In **Tdarr**, use a CPU encoder (e.g. `libx265`) instead of `hevc_nvenc`, or skip Tdarr.

> A future release may split the GPU config into an opt-in `docker-compose.gpu.yml` so the
> base stack is GPU-less by default and GPU is added with `-f docker-compose.gpu.yml`. Until
> then, the manual edit above is the way to go GPU-less.

---

## 4. VPN (Gluetun)

Gluetun needs the `/dev/net/tun` device and the `NET_ADMIN` capability. Both work under
**Docker Desktop (WSL2 / macOS VM)** with no changes. If the VPN container fails to start on
Windows, confirm you're on the **WSL2** backend (not the legacy Hyper-V backend).

---

## 5. Quick step-by-step

### Windows (WSL2)
```powershell
# 1. Install Docker Desktop (WSL2 backend) + a WSL2 distro (Ubuntu)
# 2. (For GPU) install NVIDIA Container Toolkit INSIDE WSL2 - see section 3
# 3. In a WSL2 shell:
git clone https://github.com/reyisaac/docker-media-server.git
cd docker-media-server
cp env.example .env
# edit .env: set *_ROOT paths (WSL2 paths are fastest), VPN creds, TZ, PUID/PGID=1000
docker compose up -d
```

### macOS
```bash
# 1. Install Docker Desktop for Mac
git clone https://github.com/reyisaac/docker-media-server.git
cd docker-media-server
cp env.example .env
# edit .env: set *_ROOT paths (/Users/you/...), VPN creds, TZ
# 2. Remove the GPU blocks from docker-compose.yml (see "Running GPU-less" above)
docker compose up -d
```

---

## 6. Support matrix

| Feature | Linux + NVIDIA | Windows (WSL2) + NVIDIA | macOS | Linux + AMD/Intel |
|---|---|---|---|---|
| Core stack (arr apps, Plex, VPN, etc.) | ✅ | ✅ | ✅ | ✅ |
| VPN kill-switch (Gluetun) | ✅ | ✅ | ✅ | ✅ |
| Tdarr GPU transcode | ✅ NVENC | ✅ NVENC | ❌ CPU only | ⚠️ VAAPI (manual) |
| Plex hardware transcode | ✅ | ✅ | ❌ software | ⚠️ VAAPI (manual) |
| `setup.sh` auto-installer | ✅ | ❌ (manual steps above) | ❌ (manual steps above) | ✅ |

The `scripts/setup.sh` auto-installer is Linux-only; on Windows/macOS follow the manual
steps above (install Docker Desktop, copy `.env`, `docker compose up -d`).
