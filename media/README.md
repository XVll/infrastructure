# Media Host

Media server, automation, and workflow services.

## Services

| Service | Port | Deploy Order | Purpose |
|---------|------|--------------|---------|
| Jellyfin | 8096 | 1st | Media server |
| Prowlarr | 9696 | 2nd | Indexer manager |
| Sonarr | 8989 | 3rd | TV automation |
| Radarr | 7878 | 4th | Movie automation |
| qBittorrent | 8080 | 5th | Download client |
| n8n | 5678 | 6th | Workflow automation |
| Paperless-ngx | 8000 | 7th | Document management |

## Quick Start

```bash
# Deploy Jellyfin first
cd /opt/homelab
op run --env-file=.env -- docker compose up -d jellyfin

# Access Jellyfin
open http://10.10.10.113:8096

# Deploy Arr stack in order
op run --env-file=.env -- docker compose up -d prowlarr
op run --env-file=.env -- docker compose up -d sonarr radarr qbittorrent

# Deploy workflow apps
op run --env-file=.env -- docker compose up -d n8n paperless
```

## Arr Stack Setup

1. **Prowlarr**: Configure indexers
2. **Sonarr/Radarr**: Add Prowlarr as indexer source
3. **qBittorrent**: Configure in Sonarr/Radarr as download client
4. **Jellyfin**: Add media folders, enable automatic scanning

## Notes

- All apps use PUID/PGID for NAS file permissions
- n8n requires PostgreSQL on db host
- Paperless requires PostgreSQL + Redis on db host
- Media files stored on NAS via VirtioFS
