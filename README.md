# Homelab Infrastructure

> Proxmox-based homelab infrastructure with Docker services, automated backups, and comprehensive monitoring

## Quick Overview

This repository contains Infrastructure-as-Code for a complete homelab setup running on Proxmox VE.

### Hardware

- **Host**: AMD Ryzen 9 9900X, 64GB DDR5, ASUS ProArt X870-E
- **Storage**: 256GB M.2 (OS), 2TB NVMe ZFS (VMs), 24TB HDD (NAS)
- **Network**: UniFi Dream Machine + Pro Max Switch

### Services

| VM | Services | IP | Status |
|----|----------|-----|--------|
| edge | Traefik, AdGuard, Authentik | 10.10.10.110 | 🚧 Planned |
| data | PostgreSQL, MongoDB, Redis, MinIO | 10.10.10.111 | 🚧 Planned |
| observability | Grafana, Prometheus, Loki | 10.10.10.112 | 🚧 Planned |
| media | Jellyfin, Arr Stack, n8n, Paperless | 10.10.10.113 | 🚧 Planned |
| coolify | Coolify (PaaS) | 10.10.10.114 | 🚧 Planned |
| nas | Xpenology NAS (24TB) | 10.10.10.115 | ✅ Running |
| homeassistant | Home Assistant | 10.10.30.110 | ✅ Running |
| pbs | Proxmox Backup Server | 10.10.10.118 | 🚧 Planned |

### Key Features

- **Docker-First**: All services in containers with docker-compose
- **Centralized Management**: Komodo web UI to manage all Docker containers
- **Automated Backups**: Proxmox Backup Server with deduplication
- **Centralized Auth**: Authentik SSO for all services
- **Secrets Management**: 1Password Service Accounts for all credentials
- **Full Observability**: Grafana + Prometheus + Loki for all VMs
- **Simple Network**: All services on VLAN 10, IoT isolated on VLAN 30
- **Smart Storage**: Hot data on ZFS, backups on NAS

## Documentation

📖 **[Complete Infrastructure Plan](INFRASTRUCTURE-PLAN.md)** - Read this for full details

The infrastructure plan includes:
- Complete architecture and network design
- Storage strategy and volume management
- Backup strategy with PBS
- Deployment workflow
- Security configuration
- UniFi firewall rules

## Quick Start

### Prerequisites

1. Proxmox VE installed and configured
2. UniFi network with VLANs configured
3. Git and Docker installed on VMs
4. NAS storage accessible via NFS
5. 1Password CLI installed (`brew install 1password-cli`)
6. 1Password Service Account token configured

### Deploy a VM

```bash
# Clone repository
cd /opt
git clone <repo-url> homelab
cd homelab/data

# Setup 1Password CLI
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"

# Generate TLS certificates (see VM README)
cd certs/postgres && <generate certs>

# Mount NAS storage
echo "10.10.10.115:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Deploy services (the .env file has 1Password references)
op run --env-file=.env -- docker compose up -d
op run --env-file=.env -- docker compose logs -f
```

## Repository Structure

```
infrastructure/
├── INFRASTRUCTURE-PLAN.md          ← Complete design document
├── README.md                       ← This file
│
├── edge/                           ← Traefik, AdGuard, Authentik
├── data/                           ← Databases (PostgreSQL, MongoDB, Redis, MinIO)
├── observability/                  ← Monitoring (Grafana, Prometheus, Loki)
├── media/                          ← Media & automation services
├── coolify/                        ← PaaS platform
├── pbs/                            ← Proxmox Backup Server setup
│
└── scripts/                        ← Helper scripts
```

Each VM directory contains:
- `docker-compose.yml` - Service definitions
- `.env.example` - Environment template
- `config/` - Service configurations (git-tracked)
- `README.md` - VM-specific documentation

## Progressive Deployment

**Start with essentials, add services as needed:**

### Phase 1: Core Infrastructure (40 min)
1. **observability** → Komodo (5 min) - Monitor everything!
2. **data** → PostgreSQL (10 min) - Core database
3. **edge** → Traefik (15 min) - Reverse proxy & SSL
4. **media** → Jellyfin (10 min) - Optional but fun!

### Phase 2: Expand As Needed
5. **observability** → Grafana, Prometheus - When you want dashboards
6. **data** → MongoDB, Redis, MinIO - When you need more databases
7. **edge** → AdGuard, Authentik - When you need DNS & SSO
8. **media** → Arr Stack - When you want automation
9. **coolify** → PaaS - When you want to deploy web apps

**See [QUICKSTART.md](./QUICKSTART.md) for step-by-step guide.**

## Network Design

### VLANs

| VLAN | Name | Subnet | Usage |
|------|------|--------|-------|
| 10 | Trusted | 10.10.10.0/24 | All homelab VMs + your devices |
| 30 | IoT | 10.10.30.0/24 | Home Assistant + smart home (isolated) |
| 40 | Guest | 10.10.40.0/24 | Guest WiFi (internet only) |
| 60 | Management | 10.10.60.0/24 | Proxmox, UniFi, switches |

### Firewall Rules

Only 3 rules needed (configured in UniFi):

1. **IoT Isolation**: Block VLAN 30 → VLAN 10, 60
2. **IoT Internet**: Allow VLAN 30 → Internet
3. **Guest Isolation**: Block VLAN 40 → All local networks

Everything else uses default allow. Simple and secure.

## Backup Strategy

### Automated VM Backups (PBS)

- **Tool**: Proxmox Backup Server
- **Schedule**: Daily at 1:00 AM
- **Retention**: 7 daily, 4 weekly, 6 monthly
- **Storage**: NAS (`/volume1/backups-pbs/`)
- **Features**: Deduplication, encryption, incremental forever

### Application Backups (Weekly)

- **Tool**: Simple bash scripts
- **Schedule**: Weekly (Sunday 4:00 AM)
- **What**: Database dumps (PostgreSQL, MongoDB)
- **Storage**: NAS (`/volume1/backups/`)
- **Purpose**: Portability and point-in-time recovery

## Storage Strategy

```
Proxmox Host (2TB ZFS)
├── VM disks (fast NVMe)
└── Docker data volumes (databases)

NAS (24TB HDD via NFS)
├── /volume1/media          → Jellyfin media library
├── /volume1/downloads      → Download clients
├── /volume1/backups        → Application backups
└── /volume1/backups-pbs    → PBS datastore (VM snapshots)
```

**Rule**: Hot data on ZFS, cold data on NAS.

## Maintenance

### Manage Containers

Use **Komodo Web UI** (http://10.10.10.112:9120) to manage all containers across all VMs.

Or use command line:

```bash
cd /opt/homelab/data
op run --env-file=.env -- docker compose ps                 # Status
op run --env-file=.env -- docker compose logs -f postgres   # Logs
op run --env-file=.env -- docker compose restart redis      # Restart
op run --env-file=.env -- docker compose pull && op run --env-file=.env -- docker compose up -d # Update
```

### Backup Status

Check PBS web UI: `https://10.10.10.118:8007`

## Secrets Management

This infrastructure uses **1Password Service Accounts** for all passwords, API keys, and secrets.

### Setup

```bash
# Install 1Password CLI
brew install 1password-cli

# Set up service account (one-time)
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
# Make it permanent
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_..."' >> ~/.zshrc
```

### Usage

All secrets are stored in 1Password and referenced in `.env` files.

**In 1Password (Server vault):**
- Store secrets (postgres, mongodb, redis, etc.)

**In your VM:**
The `.env` file contains 1Password references like:
```
POSTGRES_PASSWORD=op://Server/postgres/password
```

Use `op run` to inject secrets at runtime:
```bash
op run --env-file=.env -- docker compose up -d
```

### Benefits

- ✅ No plaintext secrets in files or environment variables
- ✅ Centralized secret management in 1Password
- ✅ Audit trail of all secret access
- ✅ Easy rotation - update in 1Password, redeploy
- ✅ Works with scripts, CI/CD, and manual deployments

## Support

- **Full Documentation**: See [INFRASTRUCTURE-PLAN.md](INFRASTRUCTURE-PLAN.md)
- **Per-VM Guides**: Check each VM's `README.md`
- **Issues**: Track in GitHub Issues

## License

Private infrastructure repository.

---

**Status**: Planning phase - VMs 1-5, 8 pending deployment
**Last Updated**: 2025-01-18
