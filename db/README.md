# DB Host

Centralized database services for the entire homelab.

## Services

| Service | Port | Deploy Order | Used By |
|---------|------|--------------|---------|
| MongoDB | 27017 | 1st | Komodo, Coolify |
| PostgreSQL | 5432 | 2nd | Authentik, Grafana, n8n, Paperless |
| Redis | 6379 | 3rd | Authentik, Paperless |
| MinIO | 9000/9001 | 4th | Loki (log storage) |

## Quick Start

```bash
# Deploy MongoDB first
cd /opt/homelab
op run --env-file=.env -- docker compose up -d mongodb

# Check logs
docker compose logs -f mongodb

# Test connection
docker exec mongodb mongosh --eval "db.adminCommand('ping')"

# Deploy others progressively (uncomment in docker-compose.yml)
op run --env-file=.env -- docker compose up -d postgres
op run --env-file=.env -- docker compose up -d redis
op run --env-file=.env -- docker compose up -d minio
```

## Connection Strings

```yaml
# MongoDB
mongodb://username:password@10.10.10.111:27017/database

# PostgreSQL
postgresql://username:password@10.10.10.111:5432/database

# Redis
redis://10.10.10.111:6379/0

# MinIO
http://10.10.10.111:9000
```

## Notes

- TLS certificates auto-generated on first deploy
- All data stored on Proxmox ZFS via VirtioFS
- No backup mounts (use proper backup tools instead)
