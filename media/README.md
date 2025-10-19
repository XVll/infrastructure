# Media - Jellyfin & Arr Stack

Media server and automation for movies, TV shows, and music.

## Overview

**VM Name:** media
**IP Address:** 10.10.10.113
**Resources:** 16GB RAM, 8 CPU cores, 200GB storage
**Network:** VLAN 10 (Trusted)

## Available Services

| Service | Port | Status |
|---------|------|--------|
| **Jellyfin** | 8096 | ← **Start here!** |
| Sonarr | 8989 | In `docker-compose.full.yml` |
| Radarr | 7878 | In `docker-compose.full.yml` |
| Prowlarr | 9696 | In `docker-compose.full.yml` |
| qBittorrent | 8080 | In `docker-compose.full.yml` |
| n8n | 5678 | In `docker-compose.full.yml` |
| Paperless-ngx | 8000 | In `docker-compose.full.yml` |

## Progressive Setup

**Start with Jellyfin, add automation later.**

## Quick Start (Jellyfin Only)

### 1. Mount NAS Media

```bash
# Create mount point
sudo mkdir -p /mnt/nas/media

# Add to /etc/fstab
echo "10.10.10.115:/volume1/media /mnt/nas/media nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Mount
sudo mount -a
```

### 2. Verify Media Folders

```bash
ls -la /mnt/nas/media/
# Should see: movies/, tv/, music/
```

### 3. Deploy Jellyfin

```bash
# Jellyfin doesn't need secrets, so no op run needed
docker compose up -d
docker compose logs -f
```

### 4. Access Jellyfin

**Direct:** http://10.10.10.113:8096
**Via Traefik:** https://jellyfin.homelab.example.com

**Initial Setup:**
1. Create admin account
2. Add media libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
   - Music: `/media/music`
3. Configure hardware transcoding (if available)
4. Set up users

That's it! Start watching your media.

## Adding Automation (Arr Stack)

When you're ready to automate downloads:

1. See `docker-compose.full.yml` for Sonarr, Radarr, Prowlarr
2. Copy services you need to `docker-compose.yml`
3. Deploy: `docker compose up -d`

**Setup order:**
1. Prowlarr (indexer management)
2. qBittorrent (download client)
3. Sonarr (TV shows)
4. Radarr (movies)

## File Structure

```
media/
├── docker-compose.yml          # Jellyfin only (start here!)
├── docker-compose.full.yml     # All media services
├── dc                          # Docker-compose wrapper
│
└── data/
    ├── jellyfin/              # Jellyfin config
    ├── sonarr/                # (when added)
    ├── radarr/                # (when added)
    └── qbittorrent/           # (when added)
```

## Monitoring

**Komodo:** http://10.10.10.112:9120
**Jellyfin:** http://10.10.10.113:8096

## Troubleshooting

**No media showing:**
```bash
# Check NFS mount
mount | grep media
ls -la /mnt/nas/media/movies

# Check Jellyfin logs
docker compose logs jellyfin
```

**Hardware transcoding not working:**
```bash
# Check if GPU is available
ls -la /dev/dri
# Should see renderD128 or similar

# In Jellyfin: Dashboard → Playback → Enable Hardware Acceleration
```

## Next Steps

1. ✅ **Jellyfin running** - You're done with Phase 1!
2. 🚧 **Add media** - Copy files to `/mnt/nas/media/`
3. 🚧 **Add Arr stack** - When you want automation (Phase 2)
4. 🚧 **Add n8n** - When you want workflows (Phase 3)

---

**Start with:** Jellyfin only (already configured!)
**Access:** https://jellyfin.homelab.example.com
