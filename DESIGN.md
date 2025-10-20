# Homelab Infrastructure Design

> Clean, progressive infrastructure build with logical service dependencies

## Design Principles

1. **One service at a time** - Build incrementally, test thoroughly
2. **Leverage shared infrastructure** - Reuse databases, reverse proxies, auth
3. **Komodo first** - Deploy monitoring/management before everything else
4. **Simple & secure** - No overengineering, practical security
5. **Clear dependencies** - Each service knows exactly what it needs

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ PROXMOX HOST (10.10.60.5)                              │
│ AMD Ryzen 9 9900X, 64GB RAM, 2TB ZFS                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  VLAN 10 (Trusted - 10.10.10.0/24)                     │
│  ├── 10.10.10.110 (edge)        Traefik, AdGuard, Authentik
│  ├── 10.10.10.111 (data)        MongoDB, PostgreSQL, Redis, MinIO
│  ├── 10.10.10.112 (observability) Komodo, Grafana, Prometheus, Loki
│  ├── 10.10.10.113 (media)       Jellyfin, Arr Stack, n8n
│  ├── 10.10.10.114 (coolify)     Coolify PaaS
│  ├── 10.10.10.115 (nas)         24TB NAS Storage
│  └── 10.10.10.118 (pbs)         Proxmox Backup Server
│                                                         │
│  VLAN 30 (IoT - 10.10.30.0/24)                         │
│  └── 10.10.30.110 (homeassistant) Home Assistant      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Network
- **VLAN 10**: All services communicate freely (no internal firewall complexity)
- **VLAN 30**: IoT isolated (blocked from VLAN 10/60, internet only)
- **NFS Mounts**: NAS storage (`10.10.10.115`) mounted on all VMs

### Storage
- **Fast (ZFS)**: VM disks, databases, configs → 2TB NVMe
- **Bulk (NAS)**: Media, backups, downloads → 24TB HDD via NFS

---

## Progressive Build Strategy

### Phase 1: Foundation (Start Here)

**Goal**: Set up databases first, then deploy Komodo to monitor everything

#### Step 1.1: Deploy MongoDB (Database)
**Host**: `data` (10.10.10.111)
**Dependencies**: None
**Purpose**: Database backend for Komodo and future services

```yaml
# data/docker-compose.yml
services:
  mongodb:
    image: mongo:7
    ports: ["10.10.10.111:27017:27017"]
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: <from 1Password>
    volumes:
      - ./data/mongodb:/data/db
      - ./config/mongodb/mongod.conf:/etc/mongod.conf:ro
```

**Access**: mongodb://10.10.10.111:27017

**Deploy**:
```bash
ssh user@10.10.10.111
cd /opt/homelab/data
op run --env-file=.env -- docker compose up -d mongodb
```

---

#### Step 1.2: Deploy Komodo (Container Management)
**Host**: `observability` (10.10.10.112)
**Dependencies**: MongoDB (data host)
**Purpose**: Web UI to manage all Docker containers across all VMs

```yaml
# observability/docker-compose.yml
services:
  komodo:
    image: ghcr.io/mbecker20/komodo:latest
    ports: ["10.10.10.112:9120:9120"]
    environment:
      KOMODO_MONGO_ADDRESS: "mongodb://admin:password@10.10.10.111:27017"
    volumes: ["komodo_data:/data"]
```

**Access**: http://10.10.10.112:9120

**Why on observability host?**
- Separates concerns: data host = databases only, observability = monitoring
- Komodo can manage containers across all VMs from central location
- Built-in automation tools you want to leverage

**Deploy**:
```bash
ssh user@10.10.10.112
cd /opt/homelab/observability
op run --env-file=.env -- docker compose up -d komodo
```

**Post-Deploy**:
- Access web UI and create admin account
- Add all VM hosts as servers in Komodo
- Test container discovery

---

### Phase 2: Shared Infrastructure

Build reusable infrastructure services that others will depend on.

#### Step 2.1: PostgreSQL
**Host**: `data` (10.10.10.111)
**Dependencies**: None
**Used By**: Authentik, Grafana, n8n, Paperless, custom apps

#### Step 2.2: Redis
**Host**: `data` (10.10.10.111)
**Dependencies**: None
**Used By**: Authentik, caching, session storage

#### Step 2.3: MinIO (S3 Storage)
**Host**: `data` (10.10.10.111)
**Dependencies**: None
**Used By**: Loki, backups, object storage needs

---

### Phase 3: Edge Services

#### Step 3.1: Traefik (Reverse Proxy)
**Host**: `edge` (10.10.10.110)
**Dependencies**: None
**Purpose**: HTTPS termination, routing, Let's Encrypt

**Why Now?**
- Before deploying web apps, have the proxy ready
- Automatic SSL for all future services

#### Step 3.2: AdGuard Home (DNS)
**Host**: `edge` (10.10.10.110)
**Dependencies**: None
**Purpose**: Network-wide DNS filtering, local DNS resolution

#### Step 3.3: Authentik (SSO)
**Host**: `edge` (10.10.10.110)
**Dependencies**: PostgreSQL (data), Redis (data)
**Purpose**: Single sign-on for all services

**Connection**:
```bash
DB: postgresql://authentik:pass@10.10.10.111:5432/authentik?sslmode=require
Cache: redis://10.10.10.111:6379/0
```

---

### Phase 4: Observability

#### Step 4.1: Grafana + Prometheus
**Host**: `observability` (10.10.10.112)
**Dependencies**: PostgreSQL (optional for dashboards)
**Purpose**: Metrics visualization, alerting

#### Step 4.2: Loki
**Host**: `observability` (10.10.10.112)
**Dependencies**: MinIO (data) for log storage
**Purpose**: Log aggregation

#### Step 4.3: Alloy (Collector)
**Host**: `observability` (10.10.10.112)
**Purpose**: Collect metrics/logs from all VMs

---

### Phase 5: Applications

#### Step 5.1: Jellyfin (Media Server)
**Host**: `media` (10.10.10.113)
**Dependencies**: NAS mounts (`/mnt/nas/media`)

#### Step 5.2: Arr Stack (Media Automation)
**Host**: `media` (10.10.10.113)
**Dependencies**: Jellyfin, NAS mounts, Traefik

#### Step 5.3: n8n (Workflow Automation)
**Host**: `media` (10.10.10.113)
**Dependencies**: PostgreSQL (data)

#### Step 5.4: Paperless-ngx (Document Management)
**Host**: `media` (10.10.10.113)
**Dependencies**: PostgreSQL (data), Redis (data)

#### Step 5.5: Coolify (PaaS)
**Host**: `coolify` (10.10.10.114)
**Dependencies**: PostgreSQL (data), MongoDB (data), Redis (data)

---

## Service Dependency Map

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
├── Prometheus → (no dependencies)
├── Loki → MinIO
└── Jellyfin → NAS

Level 2 (Depends on Level 0-1):
├── Grafana → Prometheus
├── Alloy → Prometheus, Loki

Level 2 (Depends on Level 0-1):
├── Arr Stack → Traefik, Jellyfin
├── n8n → PostgreSQL
├── Paperless → PostgreSQL, Redis
└── Coolify → PostgreSQL, MongoDB, Redis
```

---

## Build Checklists by VM

### data (10.10.10.111) - DATABASES ONLY

**Services to Build** (in order):
- [ ] 1. MongoDB (document database - required by Komodo)
- [ ] 2. PostgreSQL (relational database)
- [ ] 3. Redis (cache & sessions)
- [ ] 4. MinIO (object storage)

**Key Points**:
- **THIS HOST ONLY HAS DATABASES** - no application services
- One `docker-compose.yml` file
- Mount NAS: `/mnt/nas/backups`
- Each service added one at a time
- Test connectivity from other VMs before moving to next

---

### observability (10.10.10.112) - KOMODO + MONITORING

**Services to Build** (in order):
- [ ] 1. Komodo (container management) → requires MongoDB from `data`
- [ ] 2. Prometheus (metrics storage)
- [ ] 3. Grafana (visualization)
- [ ] 4. Loki (log aggregation) → requires MinIO from `data`
- [ ] 5. Alloy (metrics/logs collector)

**Key Points**:
- **Komodo deployed HERE** (not on data host)
- Komodo connects to MongoDB on data host (10.10.10.111:27017)
- Use Komodo web UI to manage all containers
- Loki uses MinIO backend for log storage
- Alloy scrapes all VMs for metrics/logs

---

### edge (10.10.10.110) - REVERSE PROXY + DNS + AUTH

**Services to Build** (in order):
- [ ] 1. Traefik (reverse proxy)
- [ ] 2. AdGuard Home (DNS)
- [ ] 3. Authentik (SSO) → requires PostgreSQL + Redis from `data`

**Key Points**:
- Traefik handles all HTTPS termination
- AdGuard becomes network DNS server (change router settings)
- Authentik connects to remote databases on data host

---

### media (10.10.10.113)

**Services to Build** (in order):
- [ ] 1. Jellyfin (media server) → requires NAS mounts
- [ ] 2. Prowlarr (indexer manager)
- [ ] 3. Sonarr (TV automation)
- [ ] 4. Radarr (Movie automation)
- [ ] 5. qBittorrent (download client)
- [ ] 6. n8n (workflows) → requires PostgreSQL from `data`
- [ ] 7. Paperless-ngx (documents) → requires PostgreSQL + Redis from `data`

**Key Points**:
- NFS mounts required: `/mnt/nas/media`, `/mnt/nas/downloads`
- Arr stack configured in sequence (Prowlarr → Sonarr/Radarr → qBittorrent → Jellyfin)
- n8n and Paperless can be added later when needed

---

### coolify (10.10.10.114)

**Services to Build**:
- [ ] 1. Coolify (one-click install) → requires PostgreSQL, MongoDB, Redis from `data`

**Key Points**:
- Uses official install script
- Configure database connections to `data` host
- Ideal for deploying custom web apps

---

## Key Configuration Patterns

### Database Connections (from other VMs)

All services connect to `data` host databases:

```yaml
# Connecting to PostgreSQL from any VM
DATABASE_URL: postgresql://user:pass@10.10.10.111:5432/dbname?sslmode=require

# Connecting to MongoDB from any VM
MONGO_URL: mongodb://user:pass@10.10.10.111:27017/dbname?tls=true

# Connecting to Redis from any VM
REDIS_URL: redis://10.10.10.111:6379/0
REDIS_PASSWORD: <password>

# Connecting to MinIO (S3) from any VM
S3_ENDPOINT: http://10.10.10.111:9000
S3_ACCESS_KEY: <key>
S3_SECRET_KEY: <secret>
```

### NFS Mounts

All VMs (except edge):
```bash
# /etc/fstab
10.10.10.115:/volume1/backups  /mnt/nas/backups  nfs  defaults,_netdev  0 0
```

Media VM additionally:
```bash
# /etc/fstab
10.10.10.115:/volume1/media     /mnt/nas/media     nfs  defaults,_netdev  0 0
10.10.10.115:/volume1/downloads /mnt/nas/downloads nfs  defaults,_netdev  0 0
```

### Traefik Integration

Services expose themselves to Traefik via labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.homelab.local`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

### Secrets Management

All secrets stored in 1Password, injected at runtime:

```yaml
# .env file
POSTGRES_PASSWORD=op://Server/postgres/password
MONGO_PASSWORD=op://Server/mongodb/password
```

Deploy command:
```bash
op run --env-file=.env -- docker compose up -d
```

---

## Deployment Workflow

### For Each Service:

1. **Prepare VM**
   ```bash
   ssh user@10.10.10.111
   cd /opt/homelab/data
   ```

2. **Edit docker-compose.yml**
   - Add ONE new service to existing file
   - Configure volumes, networks, ports

3. **Update .env**
   - Add required 1Password references
   - Test secret injection: `op run --env-file=.env -- env | grep PASSWORD`

4. **Deploy**
   ```bash
   op run --env-file=.env -- docker compose up -d <service-name>
   op run --env-file=.env -- docker compose logs -f <service-name>
   ```

5. **Verify**
   - Check health in Komodo web UI
   - Test connectivity (curl, psql, mongosh, etc.)
   - Verify logs show no errors

6. **Move to Next Service**

---

## Important Notes

### Do NOT Do This:
- ❌ Deploy all services at once
- ❌ Have multiple docker-compose files per VM
- ❌ Create `.full.yml` variants
- ❌ Duplicate documentation across VMs
- ❌ Hardcode secrets in files

### DO This:
- ✅ One service at a time
- ✅ One docker-compose.yml per VM
- ✅ Test thoroughly before proceeding
- ✅ Use Komodo to monitor deployments
- ✅ Reuse shared infrastructure (databases, proxy, auth)
- ✅ Keep secrets in 1Password

---

## Current Status

**Deployed**:
- [ ] NAS (10.10.10.115) - Storage backend
- [ ] PBS (10.10.10.118) - Backup system

**Next Steps**:
1. Deploy Komodo + MongoDB on `data` host
2. Add PostgreSQL, Redis, MinIO to `data` host
3. Deploy Traefik on `edge` host
4. Continue progressive build...

---

## 1Password Secrets Management

All passwords and secrets are stored in **1Password** and injected at runtime using the 1Password CLI.

### 1Password Structure

**Vault**: `Server`

**Items** (create these in 1Password):

```
Server/
├── mongodb
│   ├── username
│   └── password
├── postgres
│   ├── username
│   └── password
├── redis
│   └── password
├── minio
│   ├── username
│   └── password
├── grafana
│   ├── username
│   └── password
└── (add more as needed)
```

### Usage

All `.env` files already contain 1Password references like:

```bash
MONGODB_ROOT_USER=op://Server/mongodb/username
MONGODB_ROOT_PASSWORD=op://Server/mongodb/password
```

**Deploy with secret injection**:

```bash
# Secrets are automatically injected by op run
op run --env-file=.env -- docker compose up -d mongodb
```

### Verify Secrets

Test that 1Password CLI can read your secrets:

```bash
# Should output the username
op read "op://Server/mongodb/username"

# Should output the password
op read "op://Server/mongodb/password"
```

If these commands work, you're ready to deploy!

---

**Last Updated**: 2025-01-20
**Version**: 2.0 (Simplified)
