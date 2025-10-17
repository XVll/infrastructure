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
| VM1 | Traefik, AdGuard, Authentik | 10.10.10.10 | 🚧 Planned |
| VM2 | PostgreSQL, MongoDB, Redis, MinIO | 10.10.10.11 | 🚧 Planned |
| VM3 | Grafana, Prometheus, Loki | 10.10.10.12 | 🚧 Planned |
| VM4 | Jellyfin, Arr Stack, n8n, Paperless | 10.10.10.13 | 🚧 Planned |
| VM5 | Coolify (PaaS) | 10.10.10.14 | 🚧 Planned |
| VM6 | Xpenology NAS (24TB) | 10.10.10.15 | ✅ Running |
| VM7 | Home Assistant | 10.10.30.10 | ✅ Running |
| VM8 | Proxmox Backup Server | 10.10.10.18 | 🚧 Planned |

### Key Features

- **Docker-First**: All services in containers with docker-compose
- **Automated Backups**: Proxmox Backup Server with deduplication
- **Centralized Auth**: Authentik SSO for all services
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

### Deploy a VM

```bash
# Clone repository
cd /opt
git clone <repo-url> homelab
cd homelab/vm2-data-tier

# Configure environment
cp .env.example .env
nano .env  # Set passwords

# Generate TLS certificates (see VM README)
cd certs/postgres && <generate certs>

# Mount NAS storage
echo "10.10.10.15:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Deploy services
docker compose up -d
docker compose logs -f
```

## Repository Structure

```
infrastructure/
├── INFRASTRUCTURE-PLAN.md          ← Complete design document
├── README.md                       ← This file
│
├── vm1-edge-services/              ← Traefik, AdGuard, Authentik
├── vm2-data-tier/                  ← Databases (PostgreSQL, MongoDB, Redis, MinIO)
├── vm3-observability/              ← Monitoring (Grafana, Prometheus, Loki)
├── vm4-media-automation/           ← Media & automation services
├── vm5-coolify/                    ← PaaS platform
├── vm8-pbs/                        ← Proxmox Backup Server setup
│
└── scripts/                        ← Helper scripts
```

Each VM directory contains:
- `docker-compose.yml` - Service definitions
- `.env.example` - Environment template
- `config/` - Service configurations (git-tracked)
- `README.md` - VM-specific documentation

## Deployment Order

Deploy VMs in this order (dependencies):

1. **VM 6** (NAS) - Already running - Provides storage for backups
2. **VM 8** (PBS) - Setup first - Enables automated backups
3. **VM 2** (Data Tier) - Foundation - All other services need databases
4. **VM 1** (Edge Services) - Core - Provides DNS, reverse proxy, SSO
5. **VM 3** (Observability) - Monitoring - Track everything
6. **VM 4** (Media) - Applications - Media and automation
7. **VM 5** (Coolify) - Optional - Deploy web apps

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

### Update Services

```bash
cd /opt/homelab/vm2-data-tier
docker compose pull
docker compose up -d
```

### View Logs

```bash
docker compose logs -f [service-name]
```

### Backup Status

Check PBS web UI: `https://10.10.10.18:8007`

## Support

- **Full Documentation**: See [INFRASTRUCTURE-PLAN.md](INFRASTRUCTURE-PLAN.md)
- **Per-VM Guides**: Check each VM's `README.md`
- **Issues**: Track in GitHub Issues

## License

Private infrastructure repository.

---

**Status**: Planning phase - VMs 1-5, 8 pending deployment
**Last Updated**: 2025-01-18
