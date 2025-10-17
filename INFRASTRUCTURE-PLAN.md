# Homelab Infrastructure Plan

> Complete infrastructure design for a Proxmox-based homelab with automated backups and monitoring

## Table of Contents

- [Overview](#overview)
- [Hardware Specifications](#hardware-specifications)
- [Architecture](#architecture)
- [Network Design](#network-design)
- [Storage Strategy](#storage-strategy)
- [Virtual Machines](#virtual-machines)
- [Backup Strategy](#backup-strategy)
- [Security](#security)
- [Deployment Workflow](#deployment-workflow)

---

## Overview

### Design Philosophy

This homelab infrastructure follows these principles:

1. **Infrastructure-as-Code**: All services defined in docker-compose files tracked in git
2. **Simple Network Design**: All services on VLAN 10 (Trusted), with IoT and Guest isolated
3. **Docker-First**: Services run in containers for portability and easy updates
4. **Automated Backups**: Proxmox Backup Server handles VM snapshots, minimal scripting needed
5. **Proper Storage Separation**: Hot data on ZFS, cold data (backups) on NAS
6. **Single Command Deployment**: `git pull && docker compose up -d` per VM
7. **Home-Friendly**: Secure but practical - no overly complex firewall rules

### Why This Approach?

- **Reproducible**: Entire infrastructure defined in git - disaster recovery is just re-deploying
- **Maintainable**: Standard Docker Compose - no custom tooling required
- **Cost-Effective**: Uses existing hardware efficiently
- **Scalable**: Easy to add new services or VMs
- **Reliable**: Automated backups with deduplication via PBS

---

## Hardware Specifications

### Proxmox Host

- **CPU**: AMD Ryzen 9 9900X (12 cores / 24 threads)
- **RAM**: 64GB DDR5
- **Motherboard**: ASUS ProArt X870-E
- **Storage**:
  - **256GB M.2 SSD**: Proxmox OS, ISOs, templates
  - **2TB NVMe ZFS Pool**: VM virtual disks (fast I/O)
  - **3x 12TB HDDs in SHR**: NAS storage (24TB usable, via Xpenology VM)
- **Hypervisor**: Proxmox VE 8.x
- **Network**: UniFi Dream Machine + Pro Max Switch

### Network Equipment

- **Router**: UniFi Dream Machine (or USG)
- **Switch**: UniFi Pro Max Switch (or managed switch with VLAN support)
- **WiFi**: UniFi APs (integrated in UDM or standalone)

---

## Architecture

```
PROXMOX HOST (AMD Ryzen 9 9900X, 64GB RAM, 2TB ZFS)
│
├── VLAN 10 (Trusted - 10.10.10.0/24) ← ALL HOMELAB SERVICES
│   │
│   ├── VM 1: Edge Services (10.10.10.10)
│   │   ├── Traefik (Reverse Proxy)
│   │   ├── AdGuard Home (DNS)
│   │   └── Authentik (SSO)
│   │
│   ├── VM 2: Data Tier (10.10.10.11)
│   │   ├── PostgreSQL
│   │   ├── MongoDB
│   │   ├── Redis
│   │   └── MinIO (S3)
│   │
│   ├── VM 3: Observability (10.10.10.12)
│   │   ├── Grafana + Prometheus
│   │   ├── Loki
│   │   └── Uptime Kuma
│   │
│   ├── VM 4: Media & Automation (10.10.10.13)
│   │   ├── Sonarr, Radarr, Prowlarr, Jellyfin
│   │   ├── qBittorrent
│   │   ├── n8n, Paperless-ngx
│   │   └── Kavita
│   │
│   ├── VM 5: Coolify (10.10.10.14)
│   │   └── Self-hosted PaaS for web apps
│   │
│   ├── VM 6: Xpenology NAS (10.10.10.15)
│   │   └── 24TB bulk storage (backups, media)
│   │
│   ├── VM 8: Proxmox Backup Server (10.10.10.18)
│   │   └── Automated VM backups with deduplication
│   │
│   └── Your devices (10.10.10.101-254)
│       └── Laptops, phones, tablets
│
├── VLAN 30 (IoT - 10.10.30.0/24) ← ISOLATED
│   ├── VM 7: Home Assistant (10.10.30.10)
│   └── Smart home devices (isolated from homelab)
│
├── VLAN 40 (Guest - 10.10.40.0/24) ← INTERNET ONLY
│   └── Guest WiFi
│
└── VLAN 60 (Management - 10.10.60.0/24) ← ADMIN ACCESS
    ├── Proxmox Host (10.10.60.5)
    ├── UniFi Controller
    └── Network switches
```

---

## Network Design

### VLAN Structure

| VLAN | Name | Subnet | Purpose | Access |
|------|------|--------|---------|--------|
| 10 | **Trusted** | `10.10.10.0/24` | All homelab VMs + your devices | Full inter-VLAN access |
| 30 | **IoT** | `10.10.30.0/24` | Home Assistant + smart home | Internet only, blocked from 10/60 |
| 40 | **Guest** | `10.10.40.0/24` | Guest WiFi | Internet only |
| 60 | **Management** | `10.10.60.0/24` | Network equipment | Admin access |

### IP Addressing

#### VLAN 10 (Trusted) - All Homelab Services

- `10.10.10.10` - VM 1: Edge Services (Traefik, AdGuard, Authentik)
- `10.10.10.11` - VM 2: Data Tier (PostgreSQL, MongoDB, Redis, MinIO)
- `10.10.10.12` - VM 3: Observability (Grafana, Prometheus, Loki)
- `10.10.10.13` - VM 4: Media & Automation (Plex, Arr stack, n8n)
- `10.10.10.14` - VM 5: Coolify (PaaS platform)
- `10.10.10.15` - VM 6: Xpenology NAS (24TB storage)
- `10.10.10.18` - VM 8: Proxmox Backup Server (PBS)
- `10.10.10.101-254` - DHCP pool for your devices

#### VLAN 30 (IoT)

- `10.10.30.10` - VM 7: Home Assistant
- `10.10.30.51-254` - Smart home devices

#### VLAN 60 (Management)

- `10.10.60.5` - Proxmox Host management interface

### Firewall Rules (UniFi)

Configure in **Settings → Security → Firewall → LAN In**

**Rule 1: IoT Isolation**
```
Name: IoT Isolation
Action: Drop
Source: VLAN 30 (IoT)
Destination: VLAN 10 (Trusted), VLAN 60 (Management)
```

**Rule 2: IoT Internet Access**
```
Name: IoT Internet Access
Action: Accept
Source: VLAN 30 (IoT)
Destination: Internet
```

**Rule 3: Guest Isolation**
```
Name: Guest Isolation
Action: Drop
Source: VLAN 40 (Guest)
Destination: All Local Networks (10.10.0.0/16)
```

**Default Behavior:**
- ✅ VLAN 10 ↔ VLAN 10: Full access (all VMs talk to each other)
- ✅ VLAN 10 → VLAN 60: Access to management interfaces
- ✅ All VLANs → Internet: Allowed
- ❌ VLAN 30/40 → VLAN 10/60: Blocked

**Result:** Simple, secure network with minimal rules. No service-to-service firewall headaches.

---

## Storage Strategy

### Storage Hierarchy

Understanding where data lives is critical for performance and space efficiency:

```
┌─────────────────────────────────────────────────────────┐
│ PROXMOX HOST                                            │
│                                                         │
│  256GB M.2 SSD          2TB ZFS Pool (VMs)             │
│  ─────────────          ──────────────────             │
│  • Proxmox OS           • VM disks (thin provisioned)  │
│  • ISOs                 • Fast NVMe for database I/O   │
│  • Templates            • Limited space - be smart!    │
└─────────────────────────────────────────────────────────┘
                            ↓
              Each VM disk contains:
              ├── OS (Ubuntu/Debian) ~8GB
              ├── Docker images ~10-20GB
              └── /opt/homelab/
                  ├── config/     ← Git-tracked configs
                  ├── certs/      ← Generated TLS certs
                  └── data/       ← Live database files
                                    (PostgreSQL, MongoDB, Redis)

                            ↓ NFS Mount

┌─────────────────────────────────────────────────────────┐
│ NAS (Xpenology VM) - 24TB HDD Storage                  │
│                                                         │
│  /volume1/                                              │
│  ├── media/              ← Media files (Plex/Jellyfin) │
│  ├── downloads/          ← Download clients            │
│  ├── backups/            ← APPLICATION BACKUPS         │
│  │   ├── vm1-edge-services/                            │
│  │   ├── vm2-data-tier/                                │
│  │   ├── vm3-observability/                            │
│  │   └── vm4-media-automation/                         │
│  └── backups-pbs/        ← PBS DATASTORE (VM backups) │
└─────────────────────────────────────────────────────────┘
```

### Storage Allocation Rules

| Data Type | Storage Location | Reason | Mount Point |
|-----------|-----------------|--------|-------------|
| **VM OS + Docker images** | 2TB ZFS pool | Fast I/O needed | (VM disk) |
| **Live database data** | 2TB ZFS pool | Fast I/O critical | `./data/postgres` |
| **Config files** | 2TB ZFS pool | Small, git-tracked | `./config/` |
| **TLS certificates** | 2TB ZFS pool | Small, fast access | `./certs/` |
| **Database backups** | NAS (24TB HDD) | Large, infrequent access | `/mnt/nas/backups/` |
| **Media files** | NAS (24TB HDD) | Massive, streaming OK | `/mnt/nas/media/` |
| **PBS VM backups** | NAS (24TB HDD) | Large, deduplicated | `/mnt/nas/backups-pbs/` |

### NFS Mounts (Configured on Each VM)

Each VM that needs NAS storage will mount:

```bash
# /etc/fstab on VM1, VM2, VM3, VM4
10.10.10.15:/volume1/backups     /mnt/nas/backups     nfs defaults,_netdev 0 0

# /etc/fstab on VM4 (Media VM) additionally mounts:
10.10.10.15:/volume1/media       /mnt/nas/media       nfs defaults,_netdev 0 0
10.10.10.15:/volume1/downloads   /mnt/nas/downloads   nfs defaults,_netdev 0 0

# /etc/fstab on VM8 (PBS) mounts:
10.10.10.15:/volume1/backups-pbs /mnt/datastore       nfs defaults,_netdev 0 0
```

**Why This Works:**
- ✅ Database data stays on fast ZFS (low latency, high IOPS)
- ✅ Backups go to cheap NAS storage (24TB capacity)
- ✅ 2TB ZFS pool doesn't fill up with backup data
- ✅ PBS deduplication saves massive space on NAS

---

## Virtual Machines

### Resource Allocation

| VM | Service | RAM | CPU | Disk | IP | Status |
|----|---------|-----|-----|------|-----|--------|
| VM 1 | Edge Services | 4GB | 2 | 30GB | 10.10.10.10 | 🚧 Planned |
| VM 2 | Data Tier | 10GB | 4 | 100GB | 10.10.10.11 | 🚧 Planned |
| VM 3 | Observability | 6GB | 4 | 80GB | 10.10.10.12 | 🚧 Planned |
| VM 4 | Media & Automation | 16GB | 8 | 200GB | 10.10.10.13 | 🚧 Planned |
| VM 5 | Coolify | 8GB | 4 | 100GB | 10.10.10.14 | 🚧 Planned |
| VM 6 | Xpenology NAS | 4GB | 4 | 24TB | 10.10.10.15 | ✅ Running |
| VM 7 | Home Assistant | 4GB | 2 | 32GB | 10.10.30.10 | ✅ Running |
| VM 8 | Proxmox Backup Server | 4GB | 2 | 32GB | 10.10.10.18 | 🚧 Planned |
| **TOTAL** | | **56GB** | **30** | **~24.7TB** | |
| **AVAILABLE** | | **8GB** | (oversubscribed) | |

> **Note**: CPU oversubscription is normal in virtualized environments. 30 virtual cores on 12 physical cores (24 threads) is acceptable for homelab workloads.

### VM Details

#### VM 1: Edge Services (10.10.10.10)

**OS**: Debian 12 + Docker
**Purpose**: Internet-facing services, authentication gateway

**Services:**
- **Traefik v3**: Reverse proxy, SSL/TLS termination, automatic Let's Encrypt
- **AdGuard Home**: Network-wide DNS filtering and ad blocking
- **Authentik**: SSO and identity provider (LDAP/OAuth2/OIDC)

**Database Connections:**
```bash
# Authentik connects to VM2
postgresql://authentik:PASSWORD@10.10.10.11:5432/authentik?sslmode=require
redis://10.10.10.11:6379/0
```

#### VM 2: Data Tier (10.10.10.11)

**OS**: Debian 12 + Docker
**Purpose**: Centralized database layer for all applications

**Services:**
- **PostgreSQL 16**: Shared relational database
- **MongoDB 7**: NoSQL document storage
- **Redis 7**: Caching and session storage (16 logical databases)
- **MinIO**: S3-compatible object storage

**Security:**
- All connections require TLS encryption
- Network isolated (only VLAN 10 access)
- Per-application database users with least privilege
- Automated backups to NAS

#### VM 3: Observability (10.10.10.12)

**OS**: Debian 12 + Docker
**Purpose**: Monitoring, metrics, logs, and uptime tracking

**Services:**
- **Grafana**: Unified observability UI
- **Prometheus**: Metrics storage (30-day retention)
- **Loki**: Log aggregation with MinIO backend
- **Uptime Kuma**: HTTP/TCP uptime monitoring

**Monitors:**
- System metrics (CPU, RAM, disk, network) on all VMs
- Docker container metrics (auto-discovered)
- Application metrics (database queries, HTTP latency)
- Logs from all Docker containers

#### VM 4: Media & Automation (10.10.10.13)

**OS**: Debian 12 + Docker
**Purpose**: Media management, downloads, automation workflows

**Services:**
- **Media**: Jellyfin, Overseerr, Plex (optional)
- **Arr Stack**: Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr
- **Downloads**: qBittorrent, SABnzbd
- **Automation**: n8n (workflows, OpenAI integration, Telegram bot)
- **Documents**: Paperless-ngx

**Storage:**
- Configs: Local SSD (`/opt/homelab/vm4-media-automation`)
- Media files: NAS NFS mount (`/mnt/nas/media`)
- Downloads: NAS NFS mount (`/mnt/nas/downloads`)

#### VM 5: Coolify (10.10.10.14)

**OS**: Ubuntu Server 22.04
**Purpose**: Self-hosted PaaS for deploying web applications

**Features:**
- Git-based deployments (GitHub/GitLab integration)
- Automatic SSL certificates
- Built-in monitoring and logging
- Staging and production environments
- One-click deployments

**Database Access:**
```bash
# Web apps deployed in Coolify connect to VM2
DATABASE_URL=postgresql://myapp:PASSWORD@10.10.10.11:5432/myapp?sslmode=require
MONGODB_URL=mongodb://myapp:PASSWORD@10.10.10.11:27017/myapp?tls=true
REDIS_URL=redis://10.10.10.11:6379/3
```

#### VM 6: Xpenology NAS (10.10.10.15)

**OS**: DSM 7 (Synology)
**Purpose**: Bulk storage for media, backups, and file sharing

**Storage:**
- 3x 12TB HDDs in SHR (Synology Hybrid RAID)
- 24TB usable capacity
- Shared via NFS/SMB to other VMs

**Shares:**
```
/volume1/media           → Plex/Jellyfin media library
/volume1/downloads       → Download client destination
/volume1/backups         → Application-level backups
/volume1/backups-pbs     → PBS datastore (VM snapshots)
```

#### VM 7: Home Assistant (10.10.30.10)

**OS**: Home Assistant OS
**VLAN**: 30 (IoT) - Isolated from homelab
**Purpose**: Smart home automation and device control

**Security:**
- On IoT VLAN (firewall-isolated from VLAN 10 and 60)
- Can reach internet for cloud integrations
- Cannot access homelab services or management interfaces

#### VM 8: Proxmox Backup Server (10.10.10.18)

**OS**: Proxmox Backup Server 3.x
**Purpose**: Automated VM backups with deduplication and encryption

**Configuration:**
- RAM: 4GB (minimum for deduplication)
- CPU: 2 cores
- Disk: 32GB (OS only)
- Datastore: NFS mount to `/volume1/backups-pbs` on NAS

**Features:**
- Block-level incremental backups
- Client-side encryption
- Automatic deduplication (saves 70-90% space)
- Backup verification and integrity checks
- Web UI for management
- Fast file-level and full VM restores

---

## Backup Strategy

### Three-Tier Backup Approach

#### Tier 1: VM Image Backups (Automated via PBS)

**What**: Full VM snapshots with incremental forever strategy
**Tool**: Proxmox Backup Server
**Frequency**: Daily at 1:00 AM
**Retention**: 7 daily, 4 weekly, 6 monthly
**Storage**: NAS (`/volume1/backups-pbs/`)
**Size**: ~150GB total (with deduplication)

**How It Works:**
```
1. Proxmox triggers scheduled backup job
2. Creates ZFS snapshot of each VM disk
3. Sends incremental blocks to PBS (10.10.10.18)
4. PBS deduplicates and encrypts data
5. PBS writes to NAS via NFS mount
6. PBS verifies backup integrity
7. Old backups auto-pruned per retention policy

Day 1: VM2 full = 80GB written
Day 2: VM2 incremental = 2GB (only changes)
Day 3: VM2 incremental = 1.5GB
...
Total space after 30 days: ~120GB (vs 2.4TB without deduplication!)
```

**Configuration:**

Proxmox UI → Datacenter → Backup:
- Schedule: Daily 01:00
- Selection: All VMs (VM1-VM5, VM8)
- Storage: pbs-nas
- Mode: Snapshot
- Retention: Use datastore settings

PBS Datastore Settings:
- Keep-daily: 7
- Keep-weekly: 4
- Keep-monthly: 6
- Keep-yearly: 1
- GC Schedule: Daily 02:30
- Prune Schedule: Daily 03:00

**Recovery:**
- Single file: Minutes (mount backup, browse filesystem)
- Full VM: 15-30 minutes (restore entire VM disk)

#### Tier 2: Application Backups (Weekly, Lightweight)

**What**: Database dumps for portability and point-in-time recovery
**Tool**: Simple bash scripts
**Frequency**: Weekly (Sunday 4:00 AM)
**Retention**: 4 weeks
**Storage**: NAS (`/volume1/backups/`)
**Size**: ~50GB total

**Why Still Needed:**
- PBS backs up the entire VM, but database dumps are:
  - Portable (can import to different infrastructure)
  - Smaller (can restore single database/table)
  - Independent of VM state

**Example Script (VM2):**
```bash
#!/bin/bash
# /usr/local/bin/backup-vm2-weekly.sh

DATE=$(date +%Y%m%d)
BACKUP_ROOT="/mnt/nas/backups/vm2-data-tier"

# PostgreSQL - dump all databases
docker exec postgres pg_dumpall -U postgres | gzip > \
  "$BACKUP_ROOT/postgres/weekly_$DATE.sql.gz"

# MongoDB - dump all databases
docker exec mongodb mongodump --archive --gzip > \
  "$BACKUP_ROOT/mongodb/weekly_$DATE.archive.gz"

# Cleanup old backups (keep 4 weeks)
find "$BACKUP_ROOT" -type f -name "weekly_*" -mtime +28 -delete

echo "✓ Weekly backup completed: $DATE"
```

**Cron:**
```bash
# Weekly on Sunday at 4 AM
0 4 * * 0 /usr/local/bin/backup-vm2-weekly.sh >> /var/log/backup-weekly.log 2>&1
```

#### Tier 3: Offsite Backups (Optional, Recommended)

**What**: Encrypted cloud backups for catastrophic failure protection
**Tool**: Restic or PBS Remote Sync
**Frequency**: Daily 5:00 AM
**Retention**: 90 days
**Storage**: Backblaze B2 / Wasabi / AWS S3
**Cost**: ~$30-50/month for 500GB

**Setup (Using Restic from NAS):**
```bash
# Install on NAS or PBS VM
export RESTIC_REPOSITORY="b2:homelab-backups"
export RESTIC_PASSWORD="your-strong-password"
export B2_ACCOUNT_ID="your-id"
export B2_ACCOUNT_KEY="your-key"

# Initialize
restic init

# Backup PBS datastore to cloud
restic backup /volume1/backups-pbs --tag daily

# Prune old backups
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
```

**Alternative:** PBS can sync directly to S3-compatible storage (built-in feature)

### Backup Summary

| Tier | What | Frequency | Space Used | Recovery Time |
|------|------|-----------|------------|---------------|
| 1. PBS VM Backups | Full VMs | Daily | ~150GB | 15-30 min |
| 2. Database Dumps | SQL dumps | Weekly | ~50GB | 5 min (import) |
| 3. Offsite (Optional) | Encrypted cloud | Daily | ~500GB | Hours (download) |

**Total NAS Storage for Backups:** ~200GB (vs 5TB+ with traditional methods!)

---

## Security

### Network Security

- ✅ VLAN segmentation (Trusted, IoT, Guest, Management)
- ✅ Firewall isolation (IoT and Guest blocked from homelab)
- ✅ TLS encryption for all database connections
- ✅ SSH key-only authentication on all VMs
- ⏱️ Fail2ban on edge VM (optional for home use)

### Access Control

- ✅ Authentik SSO for all services
- ✅ Per-application database users with least privilege
- ✅ Strong passwords (32+ character, generated)
- ⏱️ MFA for critical services (Proxmox, PBS, Authentik)

### Data Protection

- ✅ Automated backups with PBS (daily)
- ✅ Encrypted backups (PBS client-side encryption)
- ✅ Database backups to separate storage (NAS)
- ✅ TLS for all inter-service communication
- ⏱️ Offsite backups (cloud storage)

### Secrets Management

**Current Approach:** Environment variables in `.env` files (git-ignored)

**Future Enhancement:** 1Password CLI with template injection
```bash
# Templates with op://vault/item/field references
op inject -i docker-compose.template.yml -o docker-compose.yml
```

---

## Deployment Workflow

### Phase 1: Infrastructure Setup

1. **Configure UniFi VLANs** (Already done - VLAN 10, 30, 40, 60)
2. **Configure Firewall Rules** (3 rules - see Network Design section)
3. **Provision VMs in Proxmox** (Create VM1-VM8 with specs above)
4. **Install Ubuntu/Debian** on each VM (except VM6, VM7, VM8)
5. **Install Docker** on VM1-VM5
6. **Setup NFS mounts** on each VM to NAS

### Phase 2: Deploy Core Services (VM6, VM8 First)

**VM 6 (NAS) - Already Running:**
- Configure shares: `media`, `downloads`, `backups`, `backups-pbs`
- Enable NFS/SMB
- Set permissions

**VM 8 (PBS) - Deploy Second:**
```bash
1. Download PBS ISO from Proxmox
2. Create VM (4GB RAM, 2 cores, 32GB disk)
3. Install PBS
4. Mount NAS: /volume1/backups-pbs → /mnt/datastore
5. Configure datastore in PBS UI
6. Add PBS to Proxmox storage
7. Create backup job in Proxmox
8. Test first backup
```

### Phase 3: Deploy Data Tier (VM2)

**VM 2 must be deployed first** - all other services depend on it.

```bash
# On VM2
cd /opt
git clone <repo-url> homelab
cd homelab/vm2-data-tier

# Generate TLS certificates
cd certs/postgres && <generate certs> && cd ../..
cd certs/mongodb && <generate certs> && cd ../..
cd certs/redis && <generate certs> && cd ../..
cd certs/minio && <generate certs> && cd ../..

# Configure environment
cp .env.example .env
nano .env  # Set passwords with: openssl rand -base64 32

# Mount NAS
echo "10.10.10.15:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Deploy
docker compose up -d
docker compose logs -f

# Initialize databases
docker exec -it postgres psql -U postgres
# CREATE DATABASE authentik; CREATE USER authentik...
```

### Phase 4: Deploy Edge Services (VM1)

```bash
# On VM1
cd /opt/homelab/vm1-edge-services
cp .env.example .env
nano .env  # Configure domain, Cloudflare, database passwords

# Mount NAS
sudo mkdir -p /mnt/nas/backups
echo "10.10.10.15:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Deploy
docker compose up -d

# Configure AdGuard: http://10.10.10.10:3000
# Configure Authentik: https://auth.homelab.local
# Update router DNS to 10.10.10.10
```

### Phase 5: Deploy Observability (VM3)

```bash
cd /opt/homelab/vm3-observability
cp .env.example .env
nano .env

sudo mkdir -p /mnt/nas/backups
echo "10.10.10.15:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

docker compose up -d

# Configure Grafana: https://grafana.homelab.local
# Import dashboards, setup alerts
```

### Phase 6: Deploy Media & Automation (VM4)

```bash
cd /opt/homelab/vm4-media-automation
cp .env.example .env
nano .env

# Mount NAS (media + downloads + backups)
sudo mkdir -p /mnt/nas/{media,downloads,backups}
cat <<EOF | sudo tee -a /etc/fstab
10.10.10.15:/volume1/media /mnt/nas/media nfs defaults,_netdev 0 0
10.10.10.15:/volume1/downloads /mnt/nas/downloads nfs defaults,_netdev 0 0
10.10.10.15:/volume1/backups /mnt/nas/backups nfs defaults,_netdev 0 0
EOF
sudo mount -a

docker compose up -d

# Configure services:
# Prowlarr → Sonarr/Radarr → qBittorrent → Jellyfin
```

### Phase 7: Deploy Coolify (VM5)

```bash
# On VM5
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

# Configure via web UI: https://coolify.homelab.local
# Add GitHub integration
# Connect to VM2 databases for deployed apps
```

### Phase 8: Verify and Test

1. ✅ All VMs accessible via SSH
2. ✅ DNS resolving via AdGuard (test from laptop)
3. ✅ HTTPS certificates issued (check Traefik dashboard)
4. ✅ Authentik SSO working
5. ✅ Databases accepting connections (test from other VMs)
6. ✅ Grafana showing metrics from all VMs
7. ✅ PBS completed first backup successfully
8. ✅ NFS mounts working (`df -h` shows NAS mounts)
9. ✅ Services can write to `/mnt/nas/backups`

---

## Repository Structure

```
infrastructure/
├── INFRASTRUCTURE-PLAN.md          ← This file (complete plan)
├── README.md                       ← Simple overview
│
├── vm1-edge-services/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config/
│   │   ├── traefik/
│   │   ├── adguard/
│   │   └── authentik/
│   ├── certs/                      ← Git-ignored, generated
│   ├── data/                       ← Git-ignored, Docker volumes
│   └── README.md
│
├── vm2-data-tier/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config/
│   │   ├── postgres/
│   │   ├── mongodb/
│   │   └── redis/
│   ├── certs/                      ← Git-ignored, generated
│   ├── data/                       ← Git-ignored, Docker volumes
│   └── README.md
│
├── vm3-observability/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config/
│   │   ├── grafana/
│   │   ├── prometheus/
│   │   └── loki/
│   ├── data/                       ← Git-ignored, Docker volumes
│   └── README.md
│
├── vm4-media-automation/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config/
│   │   ├── arr-stack/
│   │   ├── n8n/
│   │   └── paperless/
│   ├── data/                       ← Git-ignored, Docker volumes
│   └── README.md
│
├── vm5-coolify/
│   └── README.md                   ← Installation notes
│
├── vm8-pbs/
│   └── README.md                   ← PBS setup guide
│
└── scripts/
    ├── generate-certs.sh           ← Helper for TLS cert generation
    ├── backup-weekly.sh            ← Weekly database dumps
    └── mount-nas.sh                ← NFS mount setup helper
```

---

## Next Steps

### Immediate (Week 1-2)

1. ✅ Review and finalize this infrastructure plan
2. 🚧 Configure UniFi firewall rules (if not already done)
3. 🚧 Provision VMs in Proxmox (VM1-VM5, VM8)
4. 🚧 Deploy PBS and configure first backup
5. 🚧 Deploy VM2 (Data Tier) - foundation for everything

### Short-term (Month 1)

6. 🚧 Deploy VM1 (Edge Services) - Traefik, AdGuard, Authentik
7. 🚧 Deploy VM3 (Observability) - Grafana, Prometheus
8. 🚧 Deploy VM4 (Media & Automation)
9. 🚧 Deploy VM5 (Coolify)
10. 🚧 Test all services and backups

### Medium-term (Month 2-3)

11. ⏱️ Create helper scripts (cert generation, NFS mounts)
12. ⏱️ Document all service configurations
13. ⏱️ Setup offsite backups (Restic to Backblaze B2)
14. ⏱️ Implement MFA for critical services
15. ⏱️ Create operational runbooks

### Long-term

16. ⏱️ Terraform for VM provisioning automation
17. ⏱️ Ansible for VM configuration management
18. ⏱️ Distributed tracing (Tempo)
19. ⏱️ Capacity planning and optimization
20. ⏱️ Staging environment for testing changes

---

**Document Version**: 1.0
**Last Updated**: 2025-01-18
**Status**: Ready for deployment
