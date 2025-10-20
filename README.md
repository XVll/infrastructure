# Homelab Infrastructure

> Progressive Docker-based infrastructure on Proxmox with centralized management

## Quick Start

1. **[VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md)** - One-time template creation
2. **[1PASSWORD-SETUP.md](1PASSWORD-SETUP.md)** - Configure secrets management
3. **Follow this README** - Deploy services progressively

---

## Hardware & Network

**Hardware:**
- AMD Ryzen 9 9900X, 64GB DDR5, ASUS ProArt X870-E
- 2TB NVMe ZFS pool (VMs + databases)
- 24TB Synology NAS (media + bulk storage)

**Network:**
- UniFi Dream Machine + Pro Max Switch
- VLAN 10 (10.10.10.0/24): All homelab services
- VLAN 30 (10.10.30.0/24): IoT (isolated)
- VLAN 60 (10.10.60.0/24): Management (Proxmox, UniFi)

---

## Architecture

### VMs & Services

| VM | IP | Services | Purpose |
|----|-----|----------|---------|
| **db** | 10.10.10.111 | MongoDB, PostgreSQL, Redis, MinIO | Centralized databases |
| **observability** | 10.10.10.112 | Komodo, Prometheus, Grafana, Loki | Monitoring & management |
| **edge** | 10.10.10.110 | Traefik, AdGuard, Authentik | Reverse proxy, DNS, SSO |
| **media** | 10.10.10.113 | Jellyfin, Arr Stack, n8n, Paperless | Media & automation |
| **coolify** | 10.10.10.114 | Coolify | PaaS for custom apps |

### Storage Strategy

**Proxmox Host:**
```
/flash/docker/homelab/          ← Single git repo
├── db/                         ← MongoDB, PostgreSQL, Redis, MinIO
├── observability/              ← Komodo, Prometheus, Grafana, Loki
├── edge/                       ← Traefik, AdGuard, Authentik
├── media/                      ← Jellyfin, Arr Stack, n8n
└── coolify/                    ← Coolify PaaS
```

**Each VM:**
- VirtioFS mounts its subdirectory to `/opt/homelab`
- All work happens in `/opt/homelab`
- Data stored on fast ZFS (Proxmox host)
- VMs are stateless and disposable

---

## Progressive Build Order

### Phase 1: Foundation

**1. Deploy MongoDB on `db` (10.10.10.111)**
   - Required by Komodo
   - Deploy first, test before continuing

**2. Deploy Komodo on `observability` (10.10.10.112)**
   - Web UI for managing all containers
   - Access: http://10.10.10.112:9120
   - Connects to MongoDB on db host

**3. Add remaining databases to `db`**
   - PostgreSQL (required by Authentik, Grafana, n8n)
   - Redis (required by Authentik, Paperless)
   - MinIO (required by Loki for log storage)

### Phase 2: Edge Services

**4. Deploy Traefik on `edge` (10.10.10.110)**
   - Reverse proxy with automatic SSL
   - Deploy before other web apps

**5. Deploy AdGuard Home on `edge`**
   - Network-wide DNS filtering
   - Configure as primary DNS in router

**6. Deploy Authentik on `edge`**
   - Single sign-on for all services
   - Requires PostgreSQL + Redis from db host

### Phase 3: Observability

**7. Add monitoring stack to `observability`**
   - Prometheus (metrics)
   - Grafana (dashboards)
   - Loki (logs, requires MinIO)
   - Alloy (collector)

### Phase 4: Applications

**8. Deploy media services on `media` (10.10.10.113)**
   - Jellyfin → Prowlarr → Sonarr/Radarr → qBittorrent
   - n8n (workflows)
   - Paperless (documents)

**9. Deploy Coolify on `coolify` (10.10.10.114)**
   - Self-hosted PaaS for custom apps

---

## VM Setup Guide

### Prerequisites

- Proxmox VE 8.x installed
- Debian 13 VM template created ([VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md))
- 1Password CLI configured ([1PASSWORD-SETUP.md](1PASSWORD-SETUP.md))
- Git repo cloned on Proxmox: `/flash/docker/homelab`

### Creating a New VM

**On Proxmox Host:**

```bash
# 1. Clone from template
qm clone <template-id> <new-vm-id> --name db

# 2. Configure VM
qm set <new-vm-id> \
  --memory 4096 \
  --cores 2 \
  --ipconfig0 ip=10.10.10.111/24,gw=10.10.10.1

# 3. Add VirtioFS mount (points to repo subdirectory)
qm set <new-vm-id> --virtfs0 /flash/docker/homelab/db,mp=docker-vm

# 4. Start VM
qm start <new-vm-id>
```

**Inside the VM:**

```bash
# 1. Set hostname
sudo hostnamectl set-hostname db

# 2. Create mount point and mount VirtioFS
sudo mkdir -p /opt/homelab
sudo mount -t virtiofs docker-vm /opt/homelab

# 3. Add to /etc/fstab for persistence
echo 'docker-vm /opt/homelab virtiofs defaults 0 0' | sudo tee -a /etc/fstab

# 4. Configure 1Password service account token
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_YOUR_TOKEN"' >> ~/.bashrc
source ~/.bashrc

# 5. Test 1Password
op read "op://Server/mongodb/username"

# 6. Navigate to working directory
cd /opt/homelab

# 7. Deploy first service
op run --env-file=.env -- docker compose up -d mongodb
```

---

## Database Connections

All services connect to centralized databases on the `db` host:

```yaml
# PostgreSQL
DATABASE_URL: postgresql://user:pass@10.10.10.111:5432/dbname

# MongoDB
MONGO_URL: mongodb://user:pass@10.10.10.111:27017/dbname

# Redis
REDIS_URL: redis://10.10.10.111:6379/0

# MinIO (S3)
S3_ENDPOINT: http://10.10.10.111:9000
```

---

## Common Operations

### Deploying a Service

```bash
# SSH into VM
ssh fx@10.10.10.111

# Navigate to working directory
cd /opt/homelab

# Deploy service
op run --env-file=.env -- docker compose up -d <service-name>

# Check logs
docker compose logs -f <service-name>

# Check status in Komodo
# Open: http://10.10.10.112:9120
```

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers
op run --env-file=.env -- docker compose up -d

# Or update specific service
docker compose pull <service-name>
op run --env-file=.env -- docker compose up -d <service-name>
```

### Updating Configuration

```bash
# On Proxmox host
cd /flash/docker/homelab
git pull

# Changes are immediately available on all VMs via VirtioFS
# Restart affected services on each VM
```

---

## Service Dependencies

```
Level 0 (No Dependencies):
├── MongoDB
├── PostgreSQL
├── Redis
├── MinIO
├── Traefik
└── AdGuard Home

Level 1 (Depends on Level 0):
├── Komodo → MongoDB
├── Authentik → PostgreSQL, Redis
├── Prometheus → (standalone)
├── Loki → MinIO
└── Jellyfin → NAS

Level 2 (Depends on Level 0-1):
├── Grafana → Prometheus, PostgreSQL (optional)
├── Alloy → Prometheus, Loki
├── Arr Stack → Traefik, Jellyfin
├── n8n → PostgreSQL
├── Paperless → PostgreSQL, Redis
└── Coolify → PostgreSQL, MongoDB, Redis
```

---

## Security

**Secrets Management:**
- All passwords stored in 1Password
- Injected at runtime with `op run`
- No plaintext secrets in git

**Network Security:**
- IoT VLAN isolated from homelab
- Traefik handles SSL for all web services
- Authentik provides SSO

**Backup Strategy:**
- Database backups via proper tools (mongodump, pg_dump)
- Proxmox Backup Server for VM snapshots
- NAS for media and bulk storage

---

## Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs <service-name>

# Check if port is already in use
sudo netstat -tulpn | grep <port>

# Verify secrets are loading
op run --env-file=.env -- env | grep PASSWORD
```

### Can't access /opt/homelab
```bash
# Check if VirtioFS is mounted
mount | grep virtiofs

# Remount if needed
sudo mount -a

# Check fstab entry
cat /etc/fstab | grep docker-vm
```

### 1Password errors
```bash
# Verify token is set
echo $OP_SERVICE_ACCOUNT_TOKEN

# Test connection
op vault list

# Check item exists
op item list --vault Server
```

---

## Repository Structure

```
homelab/
├── README.md                   ← This file
├── VM-TEMPLATE-SETUP.md        ← One-time template setup
├── 1PASSWORD-SETUP.md          ← Secrets management setup
│
├── db/                         ← Database services
│   ├── docker-compose.yml
│   ├── .env
│   ├── mongodb/
│   ├── postgres/
│   ├── redis/
│   └── minio/
│
├── observability/              ← Monitoring & management
│   ├── docker-compose.yml
│   ├── .env
│   └── config/
│
├── edge/                       ← Reverse proxy, DNS, auth
│   ├── docker-compose.yml
│   ├── .env
│   └── config/
│
├── media/                      ← Media & automation
│   ├── docker-compose.yml
│   ├── .env
│   └── config/
│
└── coolify/                    ← PaaS
    └── README.md
```

---

## Next Steps

1. ✅ Create VM template: [VM-TEMPLATE-SETUP.md](VM-TEMPLATE-SETUP.md)
2. ✅ Configure 1Password: [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md)
3. ⏳ Create `db` VM and deploy MongoDB
4. ⏳ Create `observability` VM and deploy Komodo
5. ⏳ Add PostgreSQL, Redis, MinIO to `db`
6. ⏳ Create `edge` VM and deploy Traefik
7. ⏳ Continue progressive build...

---

**Status**: Ready for deployment
**Last Updated**: 2025-01-20
