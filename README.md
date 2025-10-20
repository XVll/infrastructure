# Homelab Infrastructure

> Clean, progressive infrastructure build with Komodo management

## Quick Links

- **[DESIGN.md](DESIGN.md)** - Complete design & build strategy (READ THIS FIRST)
- **[VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md)** - Prepare VM templates

## Overview

This homelab runs on Proxmox with Docker-based services across multiple VMs. The approach is simple: **one service at a time, tested thoroughly**.

### Hardware

- **Host**: AMD Ryzen 9 9900X, 64GB DDR5, ASUS ProArt X870-E
- **Storage**: 2TB ZFS (VMs + databases), 24TB NAS (media + backups)
- **Network**: UniFi Dream Machine + Pro Max Switch

### VMs & Services

| VM | IP | Services | Status |
|----|-----|----------|--------|
| **db** | 10.10.10.111 | MongoDB, PostgreSQL, Redis, MinIO | Databases only - Start here |
| **observability** | 10.10.10.112 | Komodo, Prometheus, Grafana, Loki, Alloy | Build 2nd |
| **edge** | 10.10.10.110 | Traefik, AdGuard, Authentik | Build 3rd |
| **media** | 10.10.10.113 | Jellyfin, Arr Stack, n8n, Paperless | Build 4th |
| **coolify** | 10.10.10.114 | Coolify (PaaS) | Build 5th |
| **nas** | 10.10.10.115 | NAS Storage | Running |
| **pbs** | 10.10.10.118 | Proxmox Backup Server | Planned |

## Build Strategy

### Phase 1: Foundation (Start Here)

**Step 1: Deploy on `db` host (10.10.10.111) - Databases Only**

1. **MongoDB** - Document database
   - Deploy: `op run --env-file=.env -- docker compose up -d mongodb`
   - Required by Komodo in next step

2. **PostgreSQL** - Relational database (uncomment in docker-compose.yml)
3. **Redis** - Cache & sessions (uncomment in docker-compose.yml)
4. **MinIO** - Object storage (uncomment in docker-compose.yml)

**Step 2: Deploy on `observability` host (10.10.10.112) - Komodo First**

1. **Komodo** - Container management web UI
   - Access: http://10.10.10.112:9120
   - Deploy: `op run --env-file=.env -- docker compose up -d komodo`
   - Connects to MongoDB on data host
   - Configure servers in web UI to manage all VMs

2. **Prometheus** - Metrics (uncomment in docker-compose.yml)
3. **Grafana** - Dashboards (uncomment in docker-compose.yml)
4. **Loki** - Logs (uncomment, connects to MinIO on data host)
5. **Alloy** - Collector (uncomment in docker-compose.yml)

**Result**: Databases centralized, Komodo watching everything

### Phase 2: Edge Services

**Deploy on `edge` host (10.10.10.110):**

1. **Traefik** - Reverse proxy + SSL
2. **AdGuard Home** - DNS server (uncomment in docker-compose.yml)
3. **Authentik** - SSO (uncomment, connects to PostgreSQL + Redis on data host)

### Phase 3: Applications

**Deploy on `media` host (10.10.10.113):**

1. **Jellyfin** - Media server
2. **Prowlarr, Sonarr, Radarr, qBittorrent** - Media automation (uncomment in docker-compose.yml)
3. **n8n** - Workflows (uncomment, connects to PostgreSQL on data host)
4. **Paperless** - Documents (uncomment, connects to PostgreSQL + Redis on data host)

### Phase 4: PaaS

**Deploy on `coolify` host (10.10.10.114):**

1. **Coolify** - Deploy custom web apps (connects to all databases on data host)

## Key Features

### Logical Host Separation

- **db host**: Databases ONLY (MongoDB, PostgreSQL, Redis, MinIO)
- **observability host**: Komodo + monitoring stack (Prometheus, Grafana, Loki)
- **edge host**: Reverse proxy, DNS, authentication
- **media host**: Applications and workflows
- No mixing of concerns - clean separation

### Shared Infrastructure

All services reuse centralized resources:

```yaml
# Any service connecting to PostgreSQL
DATABASE_URL: postgresql://user:pass@10.10.10.111:5432/dbname

# Any service connecting to MongoDB
MONGO_URL: mongodb://user:pass@10.10.10.111:27017/dbname

# Any service connecting to Redis
REDIS_URL: redis://10.10.10.111:6379/0

# Any service connecting to MinIO (S3)
S3_ENDPOINT: http://10.10.10.111:9000
```

### Progressive Build

Each VM has ONE `docker-compose.yml` with services commented out. Build incrementally:

```bash
# Step 1: Deploy first service
op run --env-file=.env -- docker compose up -d komodo

# Step 2: Uncomment next service in docker-compose.yml
nano docker-compose.yml  # Uncomment mongodb section

# Step 3: Deploy next service
op run --env-file=.env -- docker compose up -d mongodb

# Step 4: Test, verify in Komodo, then repeat
```

### Security

- **Secrets**: All passwords in 1Password, injected with `op run`
- **Network**: Services on VLAN 10, IoT isolated on VLAN 30
- **TLS**: Traefik handles SSL for all services
- **Backups**: Proxmox Backup Server (PBS) for VM snapshots

## Quick Start

### Prerequisites

1. Proxmox VE installed
2. NAS running at 10.10.10.115
3. UniFi network with VLANs configured
4. VM template created ([VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md))
5. 1Password CLI installed: `brew install 1password-cli`
6. 1Password Service Account token configured

### Deploy First VM (db) - Databases Only

**See [VM-SETUP-CHECKLIST.md](VM-SETUP-CHECKLIST.md) for complete setup guide.**

```bash
# On your workstation
ssh fx@10.10.10.111

# Clone repo to VirtioFS mount
cd /mnt/flash/docker/db
git clone <your-repo-url> .

# Generate TLS certificates
bash generate-certs.sh

# Configure 1Password token
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_YOUR_TOKEN"' >> ~/.bashrc
source ~/.bashrc

# Deploy MongoDB (first service - required by Komodo)
op run --env-file=.env -- docker compose up -d mongodb

# Check logs
docker compose logs -f mongodb

# Test connection
docker exec -it mongodb mongosh --eval "db.adminCommand('ping')"
```

### Deploy Second VM (observability) - Komodo

```bash
# On your workstation
ssh fx@10.10.10.112

# Clone repo to VirtioFS mount
cd /mnt/flash/docker/observability
git clone <your-repo-url> .

# Deploy Komodo (connects to MongoDB on data host)
op run --env-file=.env -- docker compose up -d komodo

# Check logs
docker compose logs -f komodo

# Access web UI
# Open: http://10.10.10.112:9120
```

### Continue Building

1. Access Komodo web UI (http://10.10.10.112:9120) - create admin account
2. Add all VM hosts as servers in Komodo UI
3. Return to db host: uncomment PostgreSQL, Redis, MinIO one by one
4. Watch containers appear in Komodo as you deploy them
5. Move to edge host (Traefik, AdGuard, Authentik)

## Repository Structure

```
infrastructure/
├── DESIGN.md                  ← READ THIS FIRST
├── README.md                  ← This file
├── VM-SETUP-CHECKLIST.md      ← Quick VM setup guide
├── VM-TEMPLATE-SETUP.md       ← VM preparation
│
├── db/
│   ├── docker-compose.yml     ← Databases (uncomment as you build)
│   ├── .env
│   ├── mongodb/               ← MongoDB data, config, certs
│   ├── postgres/              ← PostgreSQL data, config, certs
│   ├── redis/                 ← Redis data, certs
│   ├── minio/                 ← MinIO data, certs
│   └── README.md
│
├── edge/
│   ├── docker-compose.yml     ← Traefik + AdGuard + Authentik
│   └── config/
│
├── observability/
│   ├── docker-compose.yml     ← Prometheus + Grafana + Loki
│   └── config/
│
├── media/
│   ├── docker-compose.yml     ← Jellyfin + Arr Stack + n8n + Paperless
│   └── config/
│
└── coolify/
    └── README.md              ← Installation notes
```

## Network Design

### VLANs

| VLAN | Name | Subnet | Purpose |
|------|------|--------|---------|
| 10 | Trusted | 10.10.10.0/24 | All homelab services |
| 30 | IoT | 10.10.30.0/24 | Home Assistant (isolated) |
| 60 | Management | 10.10.60.0/24 | Proxmox, UniFi |

### Firewall Rules (UniFi)

Only 3 rules needed:

1. **Block IoT → Trusted**: Drop VLAN 30 → VLAN 10
2. **Allow IoT → Internet**: Accept VLAN 30 → Internet
3. **Block Guest → Local**: Drop VLAN 40 → 10.10.0.0/16

Everything else: default allow. Simple and secure.

## Storage Strategy

```
Proxmox Host (2TB ZFS)
├── VM disks
└── Docker volumes (databases)

NAS (24TB via NFS)
├── /volume1/media          → Jellyfin
├── /volume1/downloads      → Arr Stack
├── /volume1/backups        → Application backups
└── /volume1/backups-pbs    → PBS datastore
```

**Rule**: Hot data on ZFS, cold data on NAS.

## Secrets Management

All secrets stored in **1Password** vault named `Server`:

```bash
# Install 1Password CLI
brew install 1password-cli

# Set service account token (one-time)
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_..."' >> ~/.zshrc

# Store secrets in 1Password (create items):
# - Server/mongodb (username, password)
# - Server/postgres (username, password)
# - Server/redis (password)
# - Server/minio (username, password)

# Deploy with secret injection
op run --env-file=.env -- docker compose up -d
```

## Maintenance

### Manage Containers

Use **Komodo Web UI** (http://10.10.10.112:9120) for:
- View all containers across all VMs
- Start/stop/restart services
- View logs
- Execute commands
- Trigger deployments

Or use command line:

```bash
cd /opt/homelab/data
op run --env-file=.env -- docker compose ps
op run --env-file=.env -- docker compose logs -f mongodb
op run --env-file=.env -- docker compose restart redis
op run --env-file=.env -- docker compose pull && docker compose up -d
```

### Update Services

```bash
# Pull new images
op run --env-file=.env -- docker compose pull

# Recreate containers with new images
op run --env-file=.env -- docker compose up -d

# Check Komodo for status
```

## Next Steps

1. ✅ Read [DESIGN.md](DESIGN.md) for complete build strategy
2. ✅ Prepare VM template: [VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md)
3. ⏳ Setup `db` VM: [VM-SETUP-CHECKLIST.md](VM-SETUP-CHECKLIST.md)
4. ⏳ Deploy MongoDB on `db` VM (databases only)
5. ⏳ Deploy Komodo on `observability` VM (connects to MongoDB)
6. ⏳ Add PostgreSQL, Redis, MinIO to `db` VM
7. ⏳ Add Prometheus, Grafana, Loki to `observability` VM
7. ⏳ Deploy `edge` VM: Traefik, AdGuard, Authentik
8. ⏳ Deploy `media` VM: Jellyfin, Arr Stack, n8n, Paperless
9. ⏳ Deploy `coolify` VM: Coolify PaaS

## Support

- **Issues**: Track in GitHub Issues
- **Docs**: All documentation in `DESIGN.md`
- **Per-VM Guides**: Check each VM's `README.md`

---

**Status**: Ready to build progressively
**Last Updated**: 2025-01-20
