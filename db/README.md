# DB Host - Database Services

Centralized database and storage layer for the homelab infrastructure.

## Overview

**VM Name:** db
**IP Address:** 10.10.10.111
**Resources:** 10GB RAM, 4 CPU cores
**Storage:** VirtioFS mount at `/mnt/flash/docker/db` (ZFS-backed)
**Network:** VLAN 10 (Trusted)

## Services

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| MongoDB 7 | 27017 | Deploy first | Required by Komodo |
| PostgreSQL 16 | 5432 | Commented out | Relational database |
| Redis 7 | 6379 | Commented out | Cache & sessions |
| MinIO | 9000/9001 | Commented out | S3-compatible object storage |

## Progressive Build Strategy

**Build one service at a time:**

1. ✅ MongoDB (required by Komodo on observability VM)
2. ⏳ PostgreSQL (required by Authentik, Grafana, n8n, Paperless)
3. ⏳ Redis (required by Authentik, Paperless)
4. ⏳ MinIO (required by Loki for log storage)

Each service has its own directory with data, config, and certs subdirectories.

## Quick Start

### VM Setup

**First time?** Follow [VM-SETUP-CHECKLIST.md](../VM-SETUP-CHECKLIST.md) for complete VM configuration.

### 1. Generate Certificates

```bash
cd certs/postgres
./generate-certs.sh  # Or follow manual steps in PROGRESSIVE-SETUP.md
```

### 2. Create 1Password Secret

```bash
op item create --category=database --title=postgres \
  --vault=Server \
  username=postgres \
  password=$(openssl rand -base64 32)
```

### 3. Deploy

```bash
op run --env-file=.env -- docker compose up -d
op run --env-file=.env -- docker compose logs -f
```

### 4. Test

```bash
docker exec -it postgres psql -U postgres
# \l to list databases
# \q to quit
```

That's it! You now have PostgreSQL running.

## Adding More Services

When you're ready to add MongoDB, Redis, or MinIO:

1. See **[PROGRESSIVE-SETUP.md](./PROGRESSIVE-SETUP.md)** for detailed steps
2. Or copy services from `docker-compose.full.yml` to `docker-compose.yml`

## Managing Containers

### Command Line

```bash
op run --env-file=.env -- docker compose up -d              # Start services
op run --env-file=.env -- docker compose down               # Stop services
op run --env-file=.env -- docker compose restart postgres   # Restart a service
op run --env-file=.env -- docker compose logs -f postgres   # Follow logs
op run --env-file=.env -- docker compose ps                 # Show status
```

### Web UI (Komodo)

Use Komodo on your `observability` VM (http://10.10.10.112:9120) to manage all containers from a web interface.

Configure Komodo to use 1Password for deployments.

## 1Password Integration

The `.env` file contains 1Password secret references like `op://Server/postgres/password`.

**Required for PostgreSQL:**
```bash
op item create --category=database --title=postgres \
  --vault=Server \
  username=postgres \
  password=$(openssl rand -base64 32)
```

**The `.env` file is already configured** with 1Password references. Just use `op run` to inject secrets at runtime.

## Connection String (PostgreSQL)

```
postgresql://postgres:PASSWORD@10.10.10.111:5432/database?sslmode=require
```

Get password from 1Password: `op read "op://Server/postgres/password"`

## File Structure

```
vm2-data-tier/
├── docker-compose.yml              # PostgreSQL only (start here!)
├── docker-compose.full.yml         # All services (use later)
├── PROGRESSIVE-SETUP.md            # Step-by-step guide
├── 1PASSWORD-SETUP.md              # 1Password details
├── dc                              # Docker-compose wrapper
├── generate-certs.sh               # TLS certificate generator
├── setup-1password-secrets.sh      # Setup all secrets (for full deployment)
│
├── config/                         # Service configurations
│   ├── postgres/
│   └── mongodb/
│
├── certs/                          # TLS certificates (generated)
│   ├── postgres/
│   ├── mongodb/
│   ├── redis/
│   └── minio/
│
└── data/                           # Database data (Docker creates)
    ├── postgres/
    ├── mongodb/
    ├── redis/
    └── minio/
```

## Tips for Learning

1. **Start small** - Just PostgreSQL first
2. **Test thoroughly** - Make sure it works before adding more
3. **Modify configs** - Experiment with `config/postgres/postgresql.conf`
4. **Break things** - It's a homelab! Learn by trying
5. **Add services gradually** - Only add what you need, when you need it

## Troubleshooting

```bash
# Check logs
op run --env-file=.env -- docker compose logs -f

# Check status
op run --env-file=.env -- docker compose ps

# Test database connection
docker exec -it postgres psql -U postgres

# Check certificates
ls -la certs/postgres/

# Test 1Password connection
op read "op://Server/postgres/password"
```

---

**Start with:** PostgreSQL only (already configured!)
**Next:** See [PROGRESSIVE-SETUP.md](./PROGRESSIVE-SETUP.md)
**Manage:** Komodo Web UI (http://10.10.10.112:9120)
