# Homelab Infrastructure

> Infrastructure-as-Code repository for home network and services

## Hardware Specifications

- **CPU**: AMD Ryzen 9 9900X (12 cores / 24 threads)
- **RAM**: 64GB DDR5
- **Motherboard**: ASUS ProArt X870-E
- **Storage**:
  - 2TB NVMe SSD (VMs, OS, application data)
  - 3x 12TB HDDs in SHR (NAS storage - 24TB usable)
- **Hypervisor**: Proxmox VE 8.x
- **Network**: UniFi Dream Machine + Pro Max Switch

---

## Architecture Overview

### Tiered Docker Infrastructure with Network Segmentation

```
PROXMOX HOST (AMD Ryzen 9 9900X, 64GB RAM)
│
├── VLAN 10 (Frontend - 10.10.10.0/24)
│   ├── VM 1: Edge Services (Docker)
│   │   ├── Traefik (Reverse Proxy)
│   │   ├── AdGuard Home (DNS)
│   │   └── Authentik (SSO)
│   ├── VM 3: Observability (Docker)
│   │   ├── Grafana + Prometheus
│   │   ├── Loki
│   │   └── Uptime Kuma
│   └── VM 6: Xpenology NAS
│       └── 24TB bulk storage
│
├── VLAN 11 (Data Tier - 10.10.11.0/24) - ISOLATED
│   └── VM 2: Databases & Storage (Docker)
│       ├── PostgreSQL
│       ├── MongoDB
│       ├── Redis
│       └── MinIO (S3)
│
├── VLAN 12 (Media Apps - 10.10.12.0/24)
│   └── VM 4: Media & Automation (Docker)
│       ├── Plex, Overseerr, SABnzbd
│       ├── Arr Stack (Radarr, Sonarr, etc.)
│       ├── n8n (AI/Telegram Bot)
│       └── Homepage, Portainer
│
├── VLAN 13 (Web Apps - 10.10.13.0/24)
│   └── VM 5: Coolify
│       └── Self-hosted PaaS for work/personal web apps
│
└── VLAN 30 (IoT - 10.10.30.0/24)
    └── VM 7: Home Assistant OS
        └── Smart home automation
```

### Design Principles

1. **Infrastructure-as-Code**: All services defined in docker-compose files in git
2. **Network Segmentation**: 5 VLANs with firewall rules for security isolation
3. **Tiered Isolation**: Edge/Data/Apps/Observability separated by failure domains
4. **Single Command Deployment**: `git pull && op inject && docker-compose up -d`
5. **Centralized Databases**: Shared PostgreSQL/MongoDB/Redis on isolated VLAN
6. **Zero-Trust Data Access**: Databases only accept connections from specific IPs/ports

---

## Network Design

### VLAN Structure

| VLAN | Name | Subnet | Purpose | Security Level |
|------|------|--------|---------|----------------|
| 10 | Frontend | `10.10.10.0/24` | Edge services, monitoring, NAS | Public-facing |
| 11 | Data Tier | `10.10.11.0/24` | Databases (isolated, no internet) | High security |
| 12 | Media Apps | `10.10.12.0/24` | Media/automation services | Trusted |
| 13 | Web Apps | `10.10.13.0/24` | Coolify deployed apps | Lower trust |
| 30 | IoT | `10.10.30.0/24` | Home Assistant + IoT devices | Isolated |
| 40 | Guest | `10.10.40.0/24` | Guest WiFi (internet only) | Untrusted |
| 60 | Management | `10.10.60.0/24` | Network equipment + Proxmox | Admin only |

### IP Addressing

#### VLAN 10 (Frontend)
- `10.10.10.10` - VM 1: Edge Services (Traefik, AdGuard, Authentik)
- `10.10.10.20` - VM 3: Observability (Grafana, Prometheus, Loki)
- `10.10.10.50` - VM 6: Xpenology NAS

#### VLAN 11 (Data Tier - Isolated)
- `10.10.11.10` - VM 2: Data Tier (PostgreSQL, MongoDB, Redis, MinIO)

#### VLAN 12 (Media Apps)
- `10.10.12.10` - VM 4: Media & Automation

#### VLAN 13 (Web Apps)
- `10.10.13.10` - VM 5: Coolify

#### VLAN 30 (IoT)
- `10.10.30.10` - VM 7: Home Assistant

#### VLAN 60 (Management)
- `10.10.60.10` - Proxmox Host

### Firewall Rules

```bash
# Edge Services (VM 1) → Data Tier (VM 2)
ALLOW: 10.10.10.10 → 10.10.11.10:5432 (Authentik → PostgreSQL)
ALLOW: 10.10.10.10 → 10.10.11.10:6379 (Authentik → Redis)

# Media Apps (VM 4) → Data Tier (VM 2)
ALLOW: 10.10.12.10 → 10.10.11.10:5432 (n8n → PostgreSQL)
ALLOW: 10.10.12.10 → 10.10.11.10:6379 (n8n → Redis)
ALLOW: 10.10.12.10 → 10.10.11.10:9000 (backups → MinIO)

# Web Apps (VM 5) → Data Tier (VM 2)
ALLOW: 10.10.13.10 → 10.10.11.10:5432 (web apps → PostgreSQL)
ALLOW: 10.10.13.10 → 10.10.11.10:27017 (web apps → MongoDB)
ALLOW: 10.10.13.10 → 10.10.11.10:6379 (web apps → Redis)

# Observability (VM 3) → All VMs
ALLOW: 10.10.10.20 → 10.10.*.*:* (metrics/log collection)

# Data Tier Isolation (VM 2)
DENY: 10.10.11.10 → * (databases never initiate outbound)

# Web Apps Isolation (VM 5)
DENY: 10.10.13.0/24 → 10.10.10.10 (can't reach Edge directly)
DENY: 10.10.13.0/24 → 10.10.12.10 (can't reach Media)
ALLOW: 10.10.13.0/24 → 10.10.11.10 (only databases)

# IoT Isolation (VM 7)
ALLOW: 10.10.30.0/24 → Internet (cloud integrations)
DENY: 10.10.30.0/24 → 10.10.10-13.* (isolated from infrastructure)
```

### DNS Configuration

- **Primary DNS**: AdGuard Home (`10.10.10.10`)
- **Internal Domain**: `homelab.local`
- **Upstream**: Cloudflare DNS (1.1.1.1)

---

## Service Inventory

### VM 1: Edge Services (Debian 12, Docker)

**VLAN**: 10 (Frontend) | **IP**: `10.10.10.10`

- **Traefik v3**: Reverse proxy, SSL/TLS termination, automatic service discovery
- **AdGuard Home**: Network-wide DNS filtering and ad blocking
- **Authentik**: SSO and identity provider (LDAP/OAuth2/OIDC)
- **Resources**: 4GB RAM, 2 cores, 30GB storage
- **Purpose**: Internet-facing edge, authentication gateway

**Database Connections**:
```bash
postgresql://10.10.11.10:5432/authentik
redis://10.10.11.10:6379/0
```

### VM 2: Data Tier (Debian 12, Docker)

**VLAN**: 11 (Data - Isolated) | **IP**: `10.10.11.10`

- **PostgreSQL 16**: Shared database (netbird, n8n, authentik, web apps)
- **MongoDB 7**: NoSQL storage for web applications
- **Redis 7**: Caching and session storage (16 logical databases)
- **MinIO**: S3-compatible object storage for backups and application assets
- **Resources**: 10GB RAM, 4 cores, 100GB storage
- **Purpose**: Centralized data tier, isolated from internet

**Security**:
- No internet access (egress blocked)
- TLS encryption for all connections
- Per-database users with least privilege
- Firewall: Only specific IPs allowed to specific ports

**Connection Examples**:
```bash
# From VM 1 (Edge)
postgresql://10.10.11.10:5432/authentik?sslmode=require
redis://10.10.11.10:6379/0

# From VM 4 (Media)
postgresql://10.10.11.10:5432/n8n?sslmode=require
redis://10.10.11.10:6379/1

# From VM 5 (Coolify)
postgresql://10.10.11.10:5432/myapp?sslmode=require
mongodb://10.10.11.10:27017/myapp
```

### VM 3: Observability (Debian 12, Docker)

**VLAN**: 10 (Frontend) | **IP**: `10.10.10.20`

- **Grafana**: Unified observability UI (metrics + logs)
- **Prometheus**: Metrics storage (30 day retention)
- **Loki**: Log aggregation with S3 backend (MinIO)
- **Uptime Kuma**: HTTP/TCP uptime monitoring
- **Grafana Alloy**: Deployed as agents on all VMs (auto-discover Docker containers)
- **Resources**: 6GB RAM, 4 cores, 80GB storage
- **Purpose**: Independent monitoring infrastructure

**Data Flow**:
```
All Services → Alloy Agents → Prometheus (metrics) + Loki (logs) →
Grafana (visualize) → Alerts → n8n → Telegram Bot
```

**Monitors**:
- System metrics (CPU, RAM, disk, network) on all VMs
- Docker container metrics (auto-discovered, per-container resources)
- Application metrics (HTTP latency, database queries, business metrics)
- All logs from Docker containers and system services

### VM 4: Media & Automation (Debian 12, Docker)

**VLAN**: 12 (Media Apps) | **IP**: `10.10.12.10`

- **Media Stack**: Plex, Overseerr, SABnzbd
- **Arr Stack**: Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr
- **AI & Automation**: n8n (workflow engine + OpenAI + Telegram Bot)
- **Management**: Homepage dashboard, Portainer
- **Resources**: 16GB RAM, 8 cores, 200GB storage
- **Purpose**: Media automation and AI orchestration

**Storage**:
- Docker configs: Local SSD (`/opt/docker`)
- Media files: NAS NFS mount (`/mnt/nas/media` - read-only)
- Downloads: NAS NFS mount (`/mnt/nas/downloads`)

**Database Connections**:
```bash
# n8n connections
postgresql://10.10.11.10:5432/n8n
redis://10.10.11.10:6379/1
```

**Notifications**: All services route alerts through n8n → Telegram Bot

### VM 5: Coolify (Ubuntu Server)

**VLAN**: 13 (Web Apps - Isolated) | **IP**: `10.10.13.10`

- **Purpose**: Self-hosted PaaS for work/personal web application deployments
- **Features**: Git-based deployments, automatic SSL, built-in monitoring, staging/production
- **Internal**: Has its own Traefik instance for routing
- **Resources**: 8GB RAM, 4 cores, 100GB storage
- **Security**: Isolated VLAN, can only access data tier

**Database Access**: Web apps deployed in Coolify connect to VM 2:
```bash
DATABASE_URL=postgresql://10.10.11.10:5432/myapp?sslmode=require
MONGODB_URL=mongodb://10.10.11.10:27017/myapp
REDIS_URL=redis://10.10.11.10:6379/2
S3_ENDPOINT=http://10.10.11.10:9000
```

**Routing**: Apps get DNS like `myapp.yourdomain.com` → Coolify's internal Traefik

### VM 6: Xpenology NAS

**VLAN**: 10 (Frontend) | **IP**: `10.10.10.50`

- **OS**: DSM 7 (Synology)
- **Storage**: 24TB usable (SHR on 3x 12TB HDDs)
- **Shares**: NFS/SMB for media library, backups, download clients
- **Resources**: 4GB RAM, 4 cores, 24TB storage
- **Purpose**: Bulk storage and backup destination

### VM 7: Home Assistant

**VLAN**: 30 (IoT - Isolated) | **IP**: `10.10.30.10`

- **OS**: Home Assistant OS
- **Purpose**: Smart home automation
- **Security**: Isolated from infrastructure VLANs
- **Resources**: 4GB RAM, 2 cores, 32GB storage

---

## Storage Organization

### Proxmox Host (2TB SSD)

- Proxmox OS: ~100GB
- VM disks: ~1.8TB (thin provisioned)
- ISOs/Templates: ~50GB

### Xpenology NAS (24TB HDD)

```
/volume1/
├── media/                    # Media library (Plex)
│   ├── movies/
│   ├── tv/
│   ├── music/
│   └── books/
│
├── downloads/               # Download clients
│   ├── complete/
│   └── incomplete/
│
├── backups/                 # All backups
│   ├── databases/          # PostgreSQL, MongoDB, Redis dumps
│   ├── docker-configs/     # /opt/docker backups
│   └── proxmox/            # VM/LXC backups
│
└── data/                    # Application data
    ├── minio/              # MinIO backend storage
    └── logs/               # Archived logs
```

### Docker Host Storage (VM 4)

```
/opt/docker/                # All Docker container configs (on SSD)
├── plex/
├── n8n/
├── arr-stack/
├── monitoring/
└── portainer/

/mnt/nas/                   # NFS mount from Xpenology
├── media/                  # Read-only for Plex
└── downloads/              # Download destination
```

### Backup Strategy

| What | Destination | Frequency | Retention | Method |
|------|-------------|-----------|-----------|--------|
| PostgreSQL | NAS: `/volume1/backups/databases/postgres/` | Daily | 30 days | pg_dump |
| MongoDB | NAS: `/volume1/backups/databases/mongodb/` | Daily | 30 days | mongodump |
| Redis | NAS: `/volume1/backups/databases/redis/` | Daily | 7 days | RDB snapshots |
| Docker configs | NAS: `/volume1/backups/docker-configs/` | Weekly | 4 weeks | rsync |
| Proxmox VMs | NAS: `/volume1/backups/proxmox/` | Weekly | 4 weeks | vzdump |

**TODO**: Implement offsite backup (NAS → Encrypted Restic → Backblaze B2)

---

## Resource Allocation

| VM | Service | RAM | CPU | Storage | VLAN | Status |
|----|---------|-----|-----|---------|------|--------|
| VM 1 | Edge Services | 4GB | 2 | 30GB | 10 | 🚧 |
| VM 2 | Data Tier | 10GB | 4 | 100GB | 11 | 🚧 |
| VM 3 | Observability | 6GB | 4 | 80GB | 10 | 🚧 |
| VM 4 | Media & Automation | 16GB | 8 | 200GB | 12 | ✅ |
| VM 5 | Coolify | 8GB | 4 | 100GB | 13 | ✅ |
| VM 6 | Xpenology NAS | 4GB | 4 | 24TB | 10 | ✅ |
| VM 7 | Home Assistant | 4GB | 2 | 32GB | 30 | ✅ |
| **TOTAL** | | **52GB** | **28** | **~24.7TB** | | |
| **AVAILABLE** | | **12GB** | (oversubscribed) | **~1.3TB** | | |

> **Note**: CPU oversubscription is normal for virtualized environments. 12 physical cores / 24 threads.

---

## Development Infrastructure

### Version Control

- **Solution**: GitHub (cloud)
- **Private repos**: All infrastructure configs
- **Purpose**: Git hosting, webhooks for CI/CD

### CI/CD Pipeline

- **Solution**: GitHub Self-Hosted Runners (Docker container on VM 4)
- **Registry**: GitHub Container Registry (ghcr.io)
- **Workflow**: `Push → Runner tests → Build image → Push to ghcr.io → Deploy`
- **Benefits**: Unlimited minutes, access to internal services

### Secrets Management

- **Solution**: 1Password CLI with template injection
- **Workflow**: Templates with `op://vault/item/field` refs → `op inject` → Deploy
- **Installed on**: Developer machines, VM 4 (Docker Host), GitHub runner
- **Secrets**: Database creds, API keys, SSL certs, service tokens

### Deployment Process

```bash
# Deploy entire infrastructure
git clone https://github.com/user/infrastructure
cd infrastructure/edge-services
op inject -i docker-compose.template.yml -o docker-compose.yml
docker-compose up -d

# Repeat for data-tier/, observability/, media-automation/
```

---

## Repository Structure

```
infrastructure/
├── edge-services/              # VM 1
│   ├── docker-compose.yml
│   ├── traefik/
│   ├── adguard/
│   └── authentik/
│
├── data-tier/                  # VM 2
│   ├── docker-compose.yml
│   ├── postgres/
│   ├── mongodb/
│   ├── redis/
│   └── minio/
│
├── observability/              # VM 3
│   ├── docker-compose.yml
│   ├── grafana/
│   ├── prometheus/
│   ├── loki/
│   └── uptime-kuma/
│
├── media-automation/           # VM 4
│   ├── docker-compose.yml
│   ├── plex/
│   ├── arr-stack/
│   └── n8n/
│
├── coolify/                    # VM 5
│   ├── README.md              # Installation notes
│   └── backup-config.sh       # Coolify backups
│
├── terraform/                  # Proxmox VM provisioning
│   ├── main.tf
│   ├── network.tf             # VLAN configuration
│   └── firewall.tf            # Firewall rules
│
├── ansible/                    # VM configuration
│   ├── site.yml
│   └── roles/
│       ├── docker/
│       ├── networking/
│       └── monitoring/
│
└── scripts/
    ├── backup.sh
    └── deploy.sh
```

---

## Migration Path (Current → Target)

### Current State
- 10 LXCs running (Traefik, AdGuard, Netbird, Authentik, PostgreSQL, MongoDB, Redis, MinIO, Grafana+Prometheus, Loki)
- Manual configuration per LXC
- Single VLAN (10.10.10.0/24)
- Difficult to reproduce

### Target State
- 7 VMs (3 new Docker VMs + 4 existing)
- All infrastructure services in docker-compose files
- 5 VLANs with firewall rules
- One-command deployment

### Migration Steps

1. ✅ Architecture redesign (this document)
2. 🚧 Create docker-compose files for each tier
3. 🚧 Provision new VMs via Terraform/Proxmox
4. 🚧 Configure VLAN segmentation in UniFi
5. 🚧 Configure firewall rules
6. 🚧 Deploy Docker stacks to new VMs
7. 🚧 Migrate databases (export from LXC → import to Docker)
8. 🚧 Update DNS records
9. 🚧 Cutover services tier-by-tier
10. 🚧 Decommission LXCs

---

## Security Hardening Checklist

### Network Security
- [ ] Implement VLAN segmentation (5 VLANs)
- [ ] Configure firewall rules (least privilege)
- [ ] Database tier isolated (no internet access)
- [ ] TLS encryption for all database connections
- [ ] Fail2ban on all VMs
- [ ] SSH key-only authentication

### Data Protection
- [ ] Automated daily database backups
- [ ] Weekly backup restore testing
- [ ] Offsite backup strategy (cloud)
- [ ] Encryption at rest for sensitive data
- [ ] Secret rotation procedures

### Access Control
- [ ] Authentik SSO enforced for all services
- [ ] Strong password policy
- [ ] MFA enabled for critical services
- [ ] Audit logging configured

### Monitoring
- [ ] Define SLOs for critical services
- [ ] Create runbooks for common incidents
- [ ] Alert routing (Critical → SMS, Warning → Telegram)
- [ ] Log retention policy

---

## Next Steps

### Immediate (Week 1-2)
1. Create docker-compose files for Edge Services (VM 1)
2. Create docker-compose files for Data Tier (VM 2)
3. Create docker-compose files for Observability (VM 3)
4. Configure VLAN segmentation in UniFi
5. Provision new VMs in Proxmox (manual or Terraform)

### Short-term (Month 1)
6. Test deployment on local environment
7. Migrate databases from LXC to Docker
8. Implement automated backup scripts
9. Configure firewall rules
10. Deploy and test each tier

### Medium-term (Month 2-3)
11. Implement Terraform for VM provisioning
12. Create Ansible playbooks for configuration
13. Set up offsite backup strategy
14. Security hardening (TLS, fail2ban, audit logs)
15. Create operational runbooks

### Long-term
16. Implement disaster recovery procedures
17. Create staging environment
18. Advanced monitoring (distributed tracing)
19. Infrastructure drift detection
20. Capacity planning and optimization

---

**Last Updated**: 2025-01-17
