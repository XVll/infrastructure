# Homelab Infrastructure

> Infrastructure-as-Code repository for home network and services

## Table of Contents

- [Hardware Specifications](#hardware-specifications)
- [Architecture Overview](#architecture-overview)
- [Infrastructure Layer](#infrastructure-layer)
- [Database Tier](#database-tier)
- [Storage Services](#storage-services)
- [Observability Infrastructure](#observability-infrastructure)
- [Virtual Machines](#virtual-machines)
- [Monitoring & Observability](#monitoring--observability)
- [Resource Allocation](#resource-allocation)
- [Network Design](#network-design)
- [Storage Organization](#storage-organization)
- [Backup Strategy](#backup-strategy)
- [Development Infrastructure](#development-infrastructure)

---

## Hardware Specifications

- **CPU**: AMD Ryzen 9 9900X (12 cores / 24 threads)
- **RAM**: 64GB DDR5
- **Motherboard**: ASUS ProArt X870-E
- **Storage**:
  - 2TB NVMe SSD (VMs, OS, application data)
  - 3x 12TB HDDs in SHR (NAS storage - 24TB usable)
- **Hypervisor**: Proxmox VE 8.x
- **Architecture Strategy**: VMs for OS-level services, LXC for infrastructure, Docker for applications

---

## Architecture Overview

```
PROXMOX HOST (AMD Ryzen 9 9900X, 64GB RAM)
│
├── INFRASTRUCTURE LAYER (LXC Containers)
│   ├── LXC 1: Traefik (Reverse Proxy)
│   ├── LXC 2: AdGuard Home (DNS & Ad Blocking)
│   ├── LXC 3: Netbird (Zero-Trust VPN)
│   └── LXC 4: Authentik (SSO)
│
├── DATABASE TIER (Isolated LXC Containers)
│   ├── LXC 5: PostgreSQL Server
│   ├── LXC 6: MongoDB Server
│   └── LXC 7: Redis Server
│
├── STORAGE SERVICES (LXC Containers)
│   └── LXC 8: MinIO (S3-Compatible Object Storage)
│
├── OBSERVABILITY INFRASTRUCTURE (LXC Containers)
│   ├── LXC 9: Grafana + Prometheus (Metrics & Visualization)
│   └── LXC 10: Loki (Log Aggregation)
│
├── VIRTUAL MACHINES
│   ├── VM 1: Xpenology DSM 7 (NAS)
│   ├── VM 2: Home Assistant
│   ├── VM 3: Docker Host (Media, Automation & AI)
│   └── VM 4: Coolify (Self-hosted PaaS for Web Apps)
│
└── MONITORING & NOTIFICATIONS
    ├── Grafana (Unified observability UI - metrics + logs)
    ├── Uptime Kuma (Service uptime)
    ├── Grafana Alloy agents (Collect metrics + logs from all hosts)
    └── n8n → Telegram Bot (Unified notification system)
```

### Design Principles

1. **Database Isolation**: Dedicated database servers (PostgreSQL, MongoDB, Redis) for maximum flexibility and production-like architecture
2. **AI-First Automation**: Central AI agent orchestrates monitoring and automation via Telegram
3. **Security-Focused**: Authentik SSO, isolated database tier, network segmentation
4. **Hybrid Storage**: Fast local SSD for configs/apps, bulk NAS storage for media
5. **Self-Hosted First**: Minimize cloud dependencies, use cloud services only where practical (e.g., OpenAI API)

---

## Infrastructure Layer

### LXC 1: Traefik (Reverse Proxy)

- **Service**: Traefik v3
- **Purpose**: Central gateway for all web services
- **Connection**: Connects remotely to Docker Host VM's Docker socket
- **Responsibilities**:
  - SSL/TLS termination
  - Automatic service discovery
  - HTTP/HTTPS routing
  - Integration with Authentik for SSO
- **Resources**: 512MB RAM, 1 CPU core, 5GB storage

### LXC 2: AdGuard Home (DNS & Ad Blocking)

- **Service**: AdGuard Home
- **Purpose**: Network-wide DNS filtering and ad blocking
- **Responsibilities**:
  - DNS resolution for entire network
  - Ad/tracker blocking
  - Custom DNS records for internal services
  - DNS-over-HTTPS/TLS support
- **Resources**: 512MB RAM, 1 CPU core, 5GB storage

### LXC 3: Netbird (VPN)

- **Service**: Netbird (WireGuard-based mesh VPN)
- **Purpose**: Zero-trust mesh VPN for secure remote access
- **Database**: Connects to LXC 5 (PostgreSQL) - `netbird` database
- **Responsibilities**:
  - Peer-to-peer VPN mesh
  - Remote access to homelab
  - Device management
- **Resources**: 1GB RAM, 2 CPU cores, 10GB storage

### LXC 4: Authentik (SSO)

- **Service**: Authentik
- **Purpose**: Centralized authentication and authorization for all services
- **Database Connections**:
  - PostgreSQL (LXC 5): `authentik` database
  - Redis (LXC 7): DB 0 for session caching
- **Integration**: Works with Traefik reverse proxy for forward authentication
- **Responsibilities**:
  - Single Sign-On (SSO)
  - LDAP provider
  - OAuth2/OIDC provider
  - User management
- **Resources**: 2GB RAM, 2 CPU cores, 10GB storage

---

## Database Tier

> **Architecture Philosophy**: Dedicated, isolated database servers instead of per-service databases for maximum flexibility, easier scaling, independent updates, and production-like architecture.

### LXC 5: PostgreSQL Server

- **Service**: PostgreSQL 16+
- **Port**: 5432
- **Architecture**: Single PostgreSQL instance, multiple databases
- **Databases**:
  - `netbird` - VPN coordination data
  - `n8n` - AI agent workflow persistence (runs on Docker Host VM 3)
  - `authentik` - SSO user/session data
  - `webapp_*` - Web application databases (deployed via Coolify)
  - `coolify_*` - Coolify internal databases
  - Future databases as needed
- **Security**:
  - Separate PostgreSQL user per database
  - Network firewall rules (only allowed services can connect)
  - Password authentication
  - Network binding to specific interface
- **Resources**: 3GB RAM, 2 CPU cores, 30GB storage

### LXC 6: MongoDB Server

- **Service**: MongoDB 7+
- **Port**: 27017
- **Architecture**: Single MongoDB instance, multiple databases
- **Databases**:
  - Document-based storage for web applications
  - NoSQL data storage
  - Future MongoDB requirements
- **Security**:
  - Role-based access control (RBAC)
  - Network firewall rules
  - Authentication enabled
  - Network binding to specific interface
- **Resources**: 3GB RAM, 2 CPU cores, 30GB storage

### LXC 7: Redis Server

- **Service**: Redis 7+
- **Port**: 6379
- **Architecture**: Single Redis instance, multiple logical databases (0-15)
- **Logical Database Allocation**:
  - DB 0: Authentik cache
  - DB 1: n8n cache/queue (runs on Docker Host VM 3)
  - DB 2: Web app sessions
  - DB 3: Application cache
  - DB 4-15: Available for future use
- **Security**:
  - Password authentication (requirepass)
  - Network firewall rules
  - Bind to specific interface
- **Resources**: 1GB RAM, 2 CPU cores, 10GB storage

### Database Tier Benefits

- ✅ Maximum isolation between database types
- ✅ Independent scaling (allocate more RAM to PostgreSQL without affecting others)
- ✅ Independent updates and maintenance windows
- ✅ Better troubleshooting (isolate issues quickly)
- ✅ Production-like architecture
- ✅ Can restart one database without affecting others
- ✅ Centralized backup strategy

### Database Connection Architecture

```
Services → Database Tier Connections
├── Netbird (LXC 3)        → PostgreSQL (LXC 5) - netbird DB
├── Authentik (LXC 4)      → PostgreSQL (LXC 5) - authentik DB
│                          → Redis (LXC 7) - DB 0
├── n8n (VM 3 Docker)      → PostgreSQL (LXC 5) - n8n DB
│                          → Redis (LXC 7) - DB 1
├── Docker Host (VM 3)     → PostgreSQL, MongoDB, Redis (as needed per container)
└── Coolify (VM 4)         → PostgreSQL, MongoDB, Redis (for deployed web apps)

Connection Examples:
- Netbird:    postgresql://10.0.20.10:5432/netbird
- Authentik:  postgresql://10.0.20.10:5432/authentik
              redis://10.0.20.12:6379/0
- n8n:        postgresql://10.0.20.10:5432/n8n
              redis://10.0.20.12:6379/1
- Web Apps:   postgresql://10.0.20.10:5432/myapp
              mongodb://10.0.20.11:27017/myapp
```

---

## Storage Services

### LXC 8: MinIO (S3-Compatible Object Storage)

- **Service**: MinIO
- **Port**: 9000 (API), 9001 (Console)
- **Purpose**: S3-compatible object storage for application files and backups
- **Why MinIO**:
  - Modern apps expect S3 API for file storage
  - Better for application assets than NFS mounts
  - Versioning and lifecycle policies built-in
  - Perfect for database backups with retention
  - Local S3 testing before deploying to cloud
- **Use Cases**:
  - Application file uploads (avatars, documents, images)
  - Database backup destination (PostgreSQL dumps, MongoDB exports)
  - n8n workflow file storage
  - Coolify deployment artifacts
  - Docker image layer caching
  - Long-term log storage (future: Loki chunks)
- **Storage Backend**: Can use local SSD or mount Xpenology NAS for actual data storage
- **Security**:
  - Access key and secret key authentication
  - Bucket policies (IAM-like permissions)
  - Network firewall rules
  - TLS encryption in transit
- **Integration**:
  - GitHub Actions: Store build artifacts
  - Backup scripts: S3-compatible target
  - Web apps: S3 SDK for file uploads
- **Resources**: 2GB RAM, 2 CPU cores, 50GB storage (+ NAS for data)

**Xpenology NAS vs MinIO**:
- **Xpenology**: Media files, bulk storage, NFS/SMB shares, manual file management
- **MinIO**: Application assets, S3 API, programmatic access, versioning, object storage

**Example S3 Connection**:
```bash
# AWS CLI compatible
aws --endpoint-url http://10.0.20.13:9000 s3 ls

# Application code (any S3 SDK)
s3://backups/postgres/daily/db-backup-2025-01-15.sql.gz
```

**Bucket Structure (Planned)**:
```
backups/
  ├── postgres/
  ├── mongodb/
  └── docker-configs/
uploads/
  ├── user-avatars/
  └── documents/
artifacts/
  ├── github-actions/
  └── coolify-builds/
logs/
  └── archived/
```

---

## Observability Infrastructure

> **Architecture Philosophy**: Unified observability stack with single pane of glass. Metrics and logs stored in dedicated infrastructure, independent from monitored services.

### LXC 9: Grafana + Prometheus (Metrics & Visualization)

- **Services**: Grafana + Prometheus
- **Ports**:
  - Grafana: 3000 (Web UI)
  - Prometheus: 9090 (API/UI)
- **Purpose**: Centralized metrics storage and unified observability visualization
- **Architecture**: Both services run in same LXC for simplicity
- **Prometheus (Metrics Storage)**:
  - Time-series database for metrics
  - Stores data from all Grafana Alloy agents
  - Retention: 30 days (configurable)
  - PromQL query engine
  - Alerting rules
- **Grafana (Visualization)**:
  - Single pane of glass for metrics + logs
  - Queries Prometheus (metrics) and Loki (logs)
  - Pre-built dashboards (import from Grafana.com)
  - Custom dashboards for web applications
  - Alert visualization
- **What It Monitors**:
  - **System metrics**: CPU, RAM, disk, network (all hosts)
  - **Docker containers**: Per-container resource usage
  - **Application metrics**: Custom metrics from web apps (HTTP requests, latencies, business metrics)
  - **Database metrics**: PostgreSQL, MongoDB, Redis performance
  - **Service health**: All infrastructure services
- **Data Sources**:
  - Grafana Alloy agents → Prometheus (metrics collection)
  - Prometheus → Grafana (metrics visualization)
  - Loki → Grafana (log visualization)
- **Why LXC**: Monitoring infrastructure should be independent from Docker hosts for reliability
- **Resources**: 3GB RAM, 2 CPU cores, 50GB storage

**Key Benefits**:
- ✅ Automatic Docker container discovery via Alloy agents
- ✅ Correlate metrics + logs in single UI
- ✅ Production-grade monitoring stack
- ✅ Custom application metrics support
- ✅ Powerful alerting engine
- ✅ Industry-standard tools

### LXC 10: Loki (Log Aggregation)

- **Service**: Grafana Loki
- **Port**: 3100 (HTTP API)
- **Purpose**: Centralized log storage and querying
- **Architecture**: Lightweight log aggregation system designed for Grafana
- **How It Works**:
  - Grafana Alloy agents ship logs from all sources
  - Loki stores logs with labels (not full-text indexing)
  - Grafana queries Loki via LogQL
  - Long-term storage in MinIO (LXC 8) via S3 API
- **Log Sources**:
  - All Docker container logs (stdout/stderr)
  - LXC system logs (journald/syslog)
  - Application logs (from web apps)
  - Infrastructure service logs
- **Storage Strategy**:
  - Recent logs (7 days): Local SSD
  - Long-term logs (30+ days): MinIO S3 backend
  - Automatic lifecycle management
- **Query Language**: LogQL (similar to PromQL)
  - Label-based filtering: `{container="n8n"} | json | level="error"`
  - Structured log parsing
  - Metric queries from logs
- **Integration**:
  - Visualized in Grafana alongside metrics
  - Click metric spike → see logs at that exact time
  - Alert on log patterns → n8n → Telegram
- **Why LXC**: Core infrastructure, needs to be independent and reliable
- **Resources**: 2GB RAM, 2 CPU cores, 20GB storage (+ MinIO for long-term)

**Key Benefits**:
- ✅ Single query interface for all logs across infrastructure
- ✅ Lightweight (not Elasticsearch-heavy)
- ✅ S3-compatible storage (uses MinIO)
- ✅ Structured log support (JSON parsing)
- ✅ Correlate with metrics in Grafana

### Grafana Alloy Agents (Collectors)

> **Note**: Lightweight agents run on all monitored hosts, not dedicated infrastructure

**What is Grafana Alloy**:
- Modern replacement for Prometheus Node Exporter + Promtail
- Single agent collects **both** metrics AND logs
- Automatically discovers Docker containers and scrapes metrics
- Ships data to Prometheus (metrics) and Loki (logs)

**Deployment Locations**:

1. **Docker Host VM 3**: Alloy as Docker container
   - Mounts Docker socket → auto-discovers all containers
   - Collects container metrics (CPU, RAM, network, disk)
   - Collects Docker logs → Loki
   - Collects system metrics → Prometheus
   - Resource usage: ~100MB RAM

2. **Coolify VM 4**: Alloy as Docker container
   - Same setup as VM 3
   - Monitors Coolify-deployed containers
   - Resource usage: ~100MB RAM

3. **Each LXC (1-10)**: Alloy as systemd service
   - Collects system metrics (CPU, RAM, disk, network)
   - Collects service logs (journald)
   - Ships to Prometheus + Loki
   - Resource usage: ~50MB RAM per LXC

4. **Proxmox Host (optional)**: Alloy as systemd service
   - Host-level metrics
   - Hypervisor monitoring
   - Critical for hardware health
   - Resource usage: ~100MB RAM

**Configuration Flow**:
```
Alloy Agent → Discovers services → Scrapes metrics/logs →
Ships to Prometheus (metrics) + Loki (logs) →
Grafana queries both → Single unified view
```

**Example: Automatic Docker Monitoring**:
```
Docker Host VM 3:
  Alloy container with /var/run/docker.sock mounted →
  Auto-discovers: plex, n8n, sonarr, radarr, etc. →
  Scrapes metrics every 15s →
  No configuration needed per container
```

---

## Virtual Machines

### VM 1: Xpenology DSM 7 (NAS)

- **OS**: Xpenology DSM 7 (Synology OS)
- **Storage**: 24TB usable (SHR on 3x 12TB HDDs)
- **Purpose**: Centralized network storage
- **Services**:
  - NFS shares (media, backups, configs)
  - SMB/CIFS shares
  - DSM management interface
- **Usage**:
  - Media library storage (Plex)
  - Database backups (PostgreSQL dumps, MongoDB exports)
  - Docker config backups
  - Proxmox VM/LXC backups
  - ISO/template storage
- **Resources**: 4GB RAM, 4 CPU cores, 24TB storage

### VM 2: Home Assistant

- **OS**: Home Assistant OS
- **Purpose**: Smart home automation platform
- **Status**: Already operational, no changes planned
- **Resources**: 4GB RAM, 2 CPU cores, 32GB storage

### VM 3: Docker Host (Media, Automation & AI)

- **OS**: Debian 12
- **Purpose**: Primary Docker container host for media, automation, and AI services
- **Management**: Portainer
- **Services Running**:
  - **AI & Automation**: n8n (workflow orchestration + OpenAI + Telegram Bot)
  - **Media**: Plex, Overseerr, SABnzbd
  - **Arr Stack**: Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr, Notifiarr (trash guides only), FlareSolverr, Tdarr
  - **Monitoring**: Homepage (custom YAML dashboard), Uptime Kuma (service uptime monitoring), Grafana Alloy agent (metrics + log collection)
- **Observability**:
  - **Grafana Alloy** container (mounts Docker socket)
  - Automatically discovers and monitors all Docker containers
  - Ships metrics → Prometheus (LXC 9)
  - Ships logs → Loki (LXC 10)
- **Database Connections**:
  - n8n → PostgreSQL (LXC 5), Redis (LXC 7)
  - Other containers can connect to PostgreSQL, MongoDB, Redis as needed
- **Notification Architecture**: All services send notifications through n8n → Telegram Bot
- **Storage Strategy**: Hybrid approach
  - **Configs**: Local SSD (`/opt/docker`)
  - **Media**: NAS via NFS mount (`/mnt/nas/media`)
- **Resources**: 16GB RAM, 8 CPU cores, 200GB storage

### VM 4: Coolify (Self-Hosted PaaS)

- **OS**: Ubuntu Server (Coolify requirement)
- **Purpose**: Self-hosted Platform-as-a-Service for web application deployments
- **Use Case**: Personal and work-related web applications/services that need proper CI/CD
- **Features**:
  - Git-based deployments
  - Automatic SSL
  - Built-in monitoring
  - Has its own internal Traefik instance
  - Staging/production environments
  - One-click rollbacks
- **Database Access**: Web applications deployed here connect to:
  - LXC 5 (PostgreSQL)
  - LXC 6 (MongoDB)
  - LXC 7 (Redis)
- **Resources**: 8GB RAM, 4 CPU cores, 100GB storage

---

## Monitoring & Observability

### Unified Observability: Grafana Stack

**Architecture**: Single pane of glass for all metrics and logs across entire infrastructure

**Stack Components**:
- **LXC 9**: Grafana + Prometheus (metrics storage + visualization)
- **LXC 10**: Loki (log aggregation)
- **Grafana Alloy agents**: Lightweight collectors on all hosts

**What It Monitors**:

1. **System Metrics** (All Hosts):
   - CPU, RAM, disk, network usage
   - Process-level metrics
   - System load and uptime
   - Temperature and hardware sensors

2. **Docker Containers** (Automatic Discovery):
   - Per-container CPU, RAM, network, disk
   - Container state and restart count
   - All containers on VM 3 (Docker Host) and VM 4 (Coolify)
   - Zero configuration required

3. **Application Metrics** (Custom):
   - HTTP request rates and latencies
   - Database query performance
   - Business metrics (orders, revenue, users)
   - Custom metrics from web apps (via Prometheus client libraries)

4. **Logs** (All Sources):
   - Docker container logs (stdout/stderr)
   - LXC system logs (journald)
   - Application logs (structured JSON)
   - Infrastructure service logs

5. **Database Health**:
   - PostgreSQL, MongoDB, Redis metrics
   - Query performance
   - Connection pools
   - Cache hit rates

**Key Features**:
- ✅ **Correlation**: View metrics + logs side by side, jump from spike to logs
- ✅ **Automatic discovery**: New containers automatically monitored
- ✅ **Single UI**: One interface for everything
- ✅ **Powerful queries**: PromQL (metrics) + LogQL (logs)
- ✅ **Custom dashboards**: Build dashboards for your web apps
- ✅ **Production-grade**: Industry-standard observability stack

**Data Flow**:
```
Services → Grafana Alloy agents → Prometheus (metrics) + Loki (logs) →
Grafana UI (query & visualize) → Alerts → n8n → Telegram
```

### Service Uptime Monitoring: Uptime Kuma

- **Purpose**: HTTP/TCP/Ping uptime monitoring for all services
- **Location**: Docker container on VM 3 (Docker Host)
- **Monitors**:
  - Service availability (HTTP status codes)
  - Response times
  - Certificate expiry
  - TCP port checks
  - Ping monitoring
- **Integration**: Sends downtime alerts to n8n → Telegram Bot
- **Why Separate**: Provides redundant monitoring (if Grafana or main Docker host fails, Uptime Kuma can still alert)

### Dashboard: Homepage

- **Type**: YAML-based, lightweight, custom dashboard
- **Location**: Docker container on VM 3 (Docker Host)
- **Purpose**: Quick overview and service launcher
- **Complements Grafana**: Homepage for quick glance, Grafana for deep dive
- **Widgets**:
  - AI Bot status (messages today, active workflows, uptime)
  - Coolify integration (projects, deployments, resources)
  - n8n workflow monitoring
  - Database health (PostgreSQL, MongoDB, Redis stats)
  - Uptime Kuma service status
  - Custom service integrations via API
  - Media library stats (Plex, Overseerr)
  - Quick links to Grafana dashboards

### Unified Notification System

- **Architecture**: All notifications flow through n8n → Telegram Bot
- **Location**: n8n runs as Docker container on VM 3
- **Components**:
  - **n8n**: Workflow orchestration engine
  - **OpenAI API**: Intelligent alert summarization and natural language processing
  - **Telegram Bot**: Primary user interface for notifications and commands
- **Database**:
  - PostgreSQL (LXC 5): Workflow persistence
  - Redis (LXC 7): Queue management and caching
- **Notification Sources**:
  - Prometheus/Grafana → n8n (metric alerts, threshold breaches)
  - Loki → n8n (log pattern alerts, error spikes)
  - Uptime Kuma → n8n (downtime alerts)
  - Arr stack services → n8n (download status, failed imports)
  - Plex → n8n (new media, playback stats)
  - Coolify → n8n (deployment notifications)
  - Database monitoring → n8n (backup status, health checks)
- **Capabilities**:
  - Two-way communication (ask questions, issue commands)
  - Intelligent alert aggregation and summarization
  - Natural language command processing
  - Execute actions across infrastructure
  - Daily health reports
  - Backup orchestration and status
- **Why Unified**: Single notification channel eliminates notification fatigue and provides AI-enhanced context

### Observability Best Practices

**For Infrastructure Services**:
- Grafana Alloy agents on all LXCs and VMs
- System metrics automatically collected
- Service logs shipped to Loki

**For Docker Containers**:
- Single Alloy agent per Docker host (automatic discovery)
- Log to stdout/stderr in JSON format
- Metrics automatically scraped

**For Web Applications**:
- Add Prometheus client library for custom metrics
- Log to stdout in structured JSON format
- Both automatically collected by Alloy agent on Docker host

### Email/SMTP Service

- **Purpose**: Outbound email for services that require SMTP
- **Use Cases**:
  - Authentik password resets
  - Coolify deployment notifications
  - Service account notifications
- **Options**:
  - **Self-hosted**: SMTP relay container (Postfix) on Docker Host
  - **External service**: Mailgun/SendGrid with custom domain (mail.onurx.com)
  - **Full mail server**: Mailcow (requires dedicated LXC, ~2GB RAM)
- **Decision**: TBD based on email volume and self-hosting preference

---

## Resource Allocation

### Summary Table

| Component | RAM | CPU Cores | Storage | Status |
|-----------|-----|-----------|---------|--------|
| **LXC 1**: Traefik | 512MB | 1 | 5GB | ✅ |
| **LXC 2**: AdGuard Home | 512MB | 1 | 5GB | ✅ |
| **LXC 3**: Netbird | 1GB | 2 | 10GB | ✅ |
| **LXC 4**: Authentik | 2GB | 2 | 10GB | ✅ |
| **LXC 5**: PostgreSQL | 3GB | 2 | 30GB | ✅ |
| **LXC 6**: MongoDB | 3GB | 2 | 30GB | ✅ |
| **LXC 7**: Redis | 1GB | 2 | 10GB | ✅ |
| **LXC 8**: MinIO | 2GB | 2 | 50GB | ✅ |
| **LXC 9**: Grafana + Prometheus | 3GB | 2 | 50GB | ✅ |
| **LXC 10**: Loki | 2GB | 2 | 20GB | ✅ |
| **VM 1**: Xpenology NAS | 4GB | 4 | 24TB | ✅ |
| **VM 2**: Home Assistant | 4GB | 2 | 32GB | ✅ |
| **VM 3**: Docker Host (incl. n8n + Alloy) | 16GB | 8 | 200GB | ✅ |
| **VM 4**: Coolify | 8GB | 4 | 100GB | ✅ |
| **TOTAL ALLOCATED** | **~50GB** | **36 cores** | **~24.7TB** | |
| **AVAILABLE** | **~14GB** | (oversubscribed) | **~1.3TB** | |

> **Note**: Ryzen 9 9900X has 12 physical cores / 24 threads. CPU oversubscription is normal and acceptable for virtualized environments as VMs/LXCs rarely use 100% simultaneously. Grafana Alloy agents are lightweight (~50-100MB RAM each) and included in their host's allocation. n8n runs as a Docker container on VM 3, so no separate resource allocation needed.

---

## Network Design

> **Status**: ✅ COMPLETED - Decision #13

### Network Equipment

- **Router**: UniFi Dream Machine
- **Switch**: UniFi Pro Max Switch
- **Management**: UniFi Network Controller

### VLAN Structure

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 1 | Default | `10.10.0.0/24` | Personal devices (phones, laptops, TVs) |
| 10 | Trusted | `10.10.10.0/24` | Infrastructure services (LXCs, VMs, databases) |
| 20 | Untrusted | `10.10.20.0/24` | Reserved for future use |
| 30 | IoT | `10.10.30.0/24` | IoT devices and Home Assistant |
| 40 | Guest | `10.10.40.0/24` | Guest WiFi (internet only) |
| 50 | DMZ | `10.10.50.0/24` | Reserved for internet-facing services |
| 60 | Management | `10.10.60.0/24` | Network equipment and hypervisor management |

### IP Addressing Scheme

#### VLAN 10 (Trusted) - `10.10.10.0/24`

**Infrastructure Layer (LXC Containers)**:
- `10.10.10.10` - Traefik (LXC 1) - Reverse Proxy
- `10.10.10.11` - AdGuard Home (LXC 2) - DNS & Ad Blocking
- `10.10.10.12` - Netbird (LXC 3) - VPN
- `10.10.10.13` - Authentik (LXC 4) - SSO

**Database Tier (LXC Containers)**:
- `10.10.10.20` - PostgreSQL (LXC 5)
- `10.10.10.21` - MongoDB (LXC 6)
- `10.10.10.22` - Redis (LXC 7)

**Storage Services (LXC Containers)**:
- `10.10.10.30` - MinIO (LXC 8) - S3-Compatible Storage

**Observability Infrastructure (LXC Containers)**:
- `10.10.10.40` - Grafana + Prometheus (LXC 9)
- `10.10.10.41` - Loki (LXC 10)

**Virtual Machines**:
- `10.10.10.50` - Xpenology NAS (VM 1)
- `10.10.10.51` - Docker Host (VM 3) - Media, Automation & AI
- `10.10.10.52` - Coolify (VM 4) - Self-hosted PaaS

**IP Ranges**:
- `10.10.10.1-9` - Reserved/Gateway
- `10.10.10.10-49` - LXC Containers (static)
- `10.10.10.50-99` - Virtual Machines (static)
- `10.10.10.100-199` - DHCP pool for dynamic services
- `10.10.10.200-254` - Reserved for future use

#### VLAN 30 (IoT) - `10.10.30.0/24`

- `10.10.30.10` - Home Assistant (VM 2)
- `10.10.30.20-254` - IoT devices (smart home, sensors, cameras)

#### VLAN 60 (Management) - `10.10.60.0/24`

- `10.10.60.1` - UniFi Router Management
- `10.10.60.2` - UniFi Switch Management
- `10.10.60.10` - Proxmox Host Management Interface

### Firewall Rules

> **Note**: Basic VLAN isolation implemented. Detailed firewall rules to be configured as needed.

**Key Security Requirements**:
- Database tier (LXC 5, 6, 7): Only authorized services can connect
- IoT VLAN: Isolated from other networks, Home Assistant can access
- Management VLAN: Restricted access from admin devices only
- Guest VLAN: Internet-only access

**Inter-VLAN Access** (to be configured):
- Default (VLAN 1) → Can access web services via Traefik (VLAN 10)
- Default (VLAN 1) → Cannot access databases or management directly
- Trusted (VLAN 10) → Can access IoT devices (for Home Assistant)
- IoT (VLAN 30) → Internet access only (for cloud integrations)

### DNS Configuration

**Primary DNS**: AdGuard Home (LXC 2) - `10.10.10.11`

**Internal DNS Records** (configured in AdGuard Home):
```
traefik.homelab.local      → 10.10.10.10
nas.homelab.local          → 10.10.10.50
plex.homelab.local         → 10.10.10.51
grafana.homelab.local      → 10.10.10.40
homeassistant.local        → 10.10.30.10
proxmox.homelab.local      → 10.10.60.10
```

### Connection Examples

**Database Connections**:
```bash
# PostgreSQL
postgresql://10.10.10.20:5432/netbird
postgresql://10.10.10.20:5432/authentik
postgresql://10.10.10.20:5432/n8n

# MongoDB
mongodb://10.10.10.21:27017/myapp

# Redis
redis://10.10.10.22:6379/0  # Authentik
redis://10.10.10.22:6379/1  # n8n
```

**MinIO S3 Storage**:
```bash
# S3 endpoint
http://10.10.10.30:9000

# Console
http://10.10.10.30:9001
```

---

## Storage Organization

> **Status**: ✅ COMPLETED - Decision #10

### Hardware Storage Overview

- **2TB NVMe SSD**: Fast storage for VMs, LXCs, databases, and application configs
- **12TB HDD**: Bulk storage for media, backups, and large files (via Xpenology NAS)

### Proxmox Host Storage (2TB SSD)

**Purpose**: VM/LXC disks, hypervisor, and high-performance storage

```
/
├── [Proxmox OS and system files]
├── /var/lib/vz/
│   ├── images/           # VM and LXC disk images
│   ├── template/         # ISO files and container templates
│   └── dump/             # Proxmox backup files (configs only)
```

**Storage Allocation**:
- Proxmox OS: ~100GB
- LXC Container disks: ~220GB (10 containers, thin provisioned)
- VM disks: ~1.5TB (allocated across 4 VMs, thin provisioned)
- ISOs/Templates: ~50GB
- Reserved: ~130GB for snapshots and growth

### Xpenology NAS (12TB HDD) - VM 1

**Purpose**: Centralized bulk storage, media library, backups

**Folder Structure**:
```
/volume1/
├── media/                    # Media library (Plex source)
│   ├── movies/              # Movie files
│   ├── tv/                  # TV show files
│   ├── music/               # Music library
│   └── books/               # eBook library
│
├── downloads/               # Download client storage
│   ├── complete/           # Completed downloads
│   ├── incomplete/         # In-progress downloads
│   └── torrents/           # Torrent files
│
├── backups/                 # All backup destinations
│   ├── databases/          # Database dumps
│   │   ├── postgres/       # PostgreSQL pg_dump files
│   │   ├── mongodb/        # MongoDB exports
│   │   └── redis/          # Redis RDB snapshots
│   ├── docker-configs/     # Docker container configs
│   │   └── opt-docker/     # Backup of /opt/docker from VM 3
│   ├── proxmox/            # Proxmox VM/LXC backups
│   ├── lxc-configs/        # LXC configuration backups
│   └── system/             # Miscellaneous system backups
│
├── data/                    # Application data storage
│   ├── minio/              # MinIO object storage backend (optional)
│   └── logs/               # Archived logs
│
└── iso/                     # ISO files and installation media
    ├── linux/
    ├── windows/
    └── proxmox/
```

**NFS/SMB Shares**:
- `/volume1/media` → Mounted by Docker Host for Plex
- `/volume1/downloads` → Mounted by Docker Host for download clients
- `/volume1/backups` → Mounted for backup scripts
- `/volume1/data` → Mounted by MinIO LXC (optional)

### Docker Host VM Storage (200GB from SSD)

**Purpose**: Docker container configs and fast-access data

**Folder Structure**:
```
/opt/docker/                    # All Docker container persistent data
├── plex/                       # Plex config and metadata (fast SSD access)
│   ├── config/
│   └── transcode/             # Temporary transcoding (fast SSD)
│
├── n8n/                        # AI automation workflows
│   └── config/
│
├── arr-stack/                  # Media automation suite
│   ├── prowlarr/
│   ├── radarr/
│   ├── sonarr/
│   ├── lidarr/
│   ├── readarr/
│   └── bazarr/
│
├── download-clients/
│   └── sabnzbd/
│
├── monitoring/
│   ├── uptime-kuma/
│   ├── homepage/
│   └── grafana-alloy/
│
└── portainer/
    └── data/

/mnt/nas/                       # NFS mount to Xpenology
├── media/                      # Read-only access to media library
└── downloads/                  # Download destination
```

**Mount Strategy**:
- Container configs: Local SSD (`/opt/docker/`)
- Media files: NFS mount from NAS (`/mnt/nas/media/`)
- Downloads: NFS mount from NAS (`/mnt/nas/downloads/`)

### LXC Container Storage

**Per-Container Disk Allocation** (on Proxmox SSD):
- LXC 1 (Traefik): 5GB
- LXC 2 (AdGuard Home): 5GB
- LXC 3 (Netbird): 10GB
- LXC 4 (Authentik): 10GB
- LXC 5 (PostgreSQL): 30GB
- LXC 6 (MongoDB): 30GB
- LXC 7 (Redis): 10GB
- LXC 8 (MinIO): 50GB (metadata only, data on NAS)
- LXC 9 (Grafana + Prometheus): 50GB
- LXC 10 (Loki): 20GB

**Database Storage Locations**:
- PostgreSQL data: `/var/lib/postgresql/` (on LXC disk)
- MongoDB data: `/var/lib/mongodb/` (on LXC disk)
- Redis data: `/var/lib/redis/` (on LXC disk)

**Note**: Databases live on fast SSD storage for performance. Backups are sent to NAS.

### MinIO Storage Strategy

**Option A** (Recommended): Local storage
- MinIO LXC stores objects on its own disk (50GB)
- Suitable for application assets and smaller files
- Simpler setup

**Option B**: NAS-backed storage
- MinIO LXC mounts NFS share from Xpenology
- Stores objects on `/volume1/data/minio/`
- Better for large object storage needs

**Decision**: Start with Option A, migrate to Option B if needed.

### Docker Volume Strategy

> **Status**: ✅ COMPLETED - Decision #11

**Strategy**: Bind mounts for all container data to `/opt/docker/`

**Why Bind Mounts**:
- ✅ Easy to backup (simple directory copy)
- ✅ Easy to inspect and modify
- ✅ Portable across Docker hosts
- ✅ Clear visibility of what's stored where
- ✅ Simple restore process

**Database Access**: All containers connect to databases via network (connection strings), NOT volume mounts

**Example docker-compose.yml**:
```yaml
services:
  plex:
    volumes:
      - /opt/docker/plex/config:/config          # Config on SSD
      - /mnt/nas/media:/media:ro                 # Media on NAS (read-only)
      - /opt/docker/plex/transcode:/transcode    # Transcode on SSD

  n8n:
    volumes:
      - /opt/docker/n8n:/home/node/.n8n          # Config on SSD
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: 10.10.10.20            # Network connection to database
```

### Backup Storage Summary

| What | Where | Frequency | Retention |
|------|-------|-----------|-----------|
| PostgreSQL dumps | NAS: `/volume1/backups/databases/postgres/` | Daily | 30 days |
| MongoDB exports | NAS: `/volume1/backups/databases/mongodb/` | Daily | 30 days |
| Redis snapshots | NAS: `/volume1/backups/databases/redis/` | Daily | 7 days |
| Docker configs | NAS: `/volume1/backups/docker-configs/` | Weekly | 4 weeks |
| LXC configs | NAS: `/volume1/backups/lxc-configs/` | Weekly | 4 weeks |
| Proxmox VM/LXC | NAS: `/volume1/backups/proxmox/` | Weekly | 4 weeks |

**Note**: Backup automation strategy to be defined in Decision #12.

---

## Backup Strategy

> **Status**: 🚧 IN PROGRESS - Decision #12

<!-- TODO: Complete backup strategy documentation -->

### What to Backup

**TODO**: Define comprehensive backup scope

- [ ] PostgreSQL databases (pg_dump)
- [ ] MongoDB databases (mongodump)
- [ ] Redis persistence files (if needed)
- [ ] Docker container configs
- [ ] LXC configurations
- [ ] Proxmox VM/LXC backups
- [ ] AI Agent conversation history / n8n workflows
- [ ] Authentik configuration

### Backup Schedule

**TODO**: Define backup frequency and retention policies

### Backup Destinations

**TODO**: Define where backups are stored

- Primary: NAS
- Secondary: [External drive? Cloud?]

### Automation

**TODO**: Define backup automation approach

- Manual scripts?
- AI Agent orchestrated backups via n8n?
- Proxmox built-in backup?

---

## Development Infrastructure

### Version Control

> **Status**: ✅ COMPLETED - Decision #14

**Solution**: GitHub (Cloud)

- **Purpose**: Git hosting and version control
- **Why Chosen**:
  - Free private repositories
  - Best Coolify integration (native support)
  - Zero maintenance overhead
  - Reliable and fast
  - Role: Version control + webhooks only (CI/CD runs locally)

### CI/CD Pipeline

> **Status**: ✅ COMPLETED - Decision #15

**Solution**: GitHub Self-Hosted Runners + Coolify

**Architecture**:
- **GitHub**: Version control and webhook triggers
- **Self-Hosted Runner**: Docker container on VM 3 (Docker Host)
- **Coolify**: Handles deployment for web applications
- **GitHub Actions**: Test/build/lint workflows (run locally on self-hosted runner)

**Setup**:
- **Runner Location**: Docker container on VM 3
- **Runner Access**: Docker socket, network access to databases (for integration tests)
- **Scaling**: Can add more runner containers as needed
- **Management**: Via Portainer

**Workflows**:

1. **For Coolify Web Apps**:
   ```
   Push to GitHub → Self-hosted runner executes GitHub Actions →
   Test/lint/build → If pass: trigger Coolify webhook → Deploy →
   Coolify notifies n8n → Telegram notification
   ```

2. **For Docker Host Containers**:
   ```
   Push to GitHub → Self-hosted runner executes GitHub Actions →
   Test/build → If pass: SSH into Docker Host or use Portainer API →
   Update container via docker-compose → n8n → Telegram notification
   ```

**Benefits**:
- ✅ Unlimited build minutes (runs on your hardware)
- ✅ Full control over build environment
- ✅ Access to internal services during builds (databases, APIs)
- ✅ Familiar GitHub Actions syntax
- ✅ Build history in GitHub UI
- ✅ No external CI/CD platform needed
- ✅ Integrates seamlessly with existing infrastructure

### Container Registry

> **Note**: No additional infrastructure required

**Solution**: GitHub Container Registry (ghcr.io)

**Why Perfect for This Setup**:
- ✅ **Free and unlimited** for public images
- ✅ **Integrated with GitHub** - images stored alongside your code
- ✅ **Simple authentication** - uses GitHub tokens
- ✅ **No additional infrastructure** to maintain
- ✅ **Private images included** in your GitHub plan

**Workflow Integration**:
```
GitHub Actions (self-hosted runner) → Build image →
Push to ghcr.io/username/app:latest →
Coolify pulls pre-built image OR Docker Host pulls and deploys
```

**Example GitHub Actions Workflow**:
```yaml
name: Build and Push

on: push

jobs:
  build:
    runs-on: self-hosted
    steps:
      - name: Login to GitHub Container Registry
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build and push
        run: |
          docker build -t ghcr.io/username/myapp:latest .
          docker push ghcr.io/username/myapp:latest
```

**Deployment Usage**:

*For Coolify*:
- Set image source to `ghcr.io/username/myapp:latest`
- Add GitHub token as registry credential in Coolify
- Coolify pulls pre-built image instead of building from source

*For Docker Host (VM 3)*:
```yaml
# docker-compose.yml
services:
  myapp:
    image: ghcr.io/username/myapp:latest
    # Docker pulls from ghcr.io automatically after authentication
```

**Authentication Setup**:
```bash
# On Docker Host VM 3 (one-time setup):
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Token stored in 1Password (op://homelab/github/container-registry-token)
# Injected during deployment workflow
```

**Image Versioning**:
- Use tags for versioning: `ghcr.io/username/myapp:v1.2.3`
- `latest` tag for current production version
- Feature branch tags: `ghcr.io/username/myapp:feature-branch-name`

### Secrets Management

> **Status**: ✅ COMPLETED - Decision #16

**Solution**: 1Password CLI with Template Injection

**Philosophy**: Seamless developer experience - reference secrets in templates, inject at deployment time. Secrets never committed to git in plain text.

**Architecture**:
- **Source of Truth**: 1Password vault ("homelab")
- **Templates**: Config files with `op://vault/item/field` references (committed to git)
- **Injection**: `op inject` CLI generates final configs with real secrets (not committed)
- **Deployment**: Use injected configs for services

**Where 1Password CLI is Installed**:
1. **Developer machines** (local development)
2. **Docker Host VM 3** (inject secrets for Docker containers)
3. **GitHub self-hosted runner** (CI/CD secret injection)

**Where 1Password CLI is NOT needed**:
- LXCs, individual Docker containers, VMs (they receive final configs with secrets already injected)

**Template Syntax**:
```yaml
# docker-compose.template.yml (committed to git)
services:
  n8n:
    environment:
      DB_PASSWORD: op://homelab/postgres/password
      OPENAI_API_KEY: op://homelab/openai/api_key
      TELEGRAM_TOKEN: op://homelab/telegram/bot_token

# Generate real config (not committed):
op inject -i docker-compose.template.yml -o docker-compose.yml
docker-compose up -d
```

**Deployment Workflow**:
```bash
# On Docker Host VM 3:
git pull  # Get latest templates
op inject -i docker/docker-compose.template.yml -o docker/docker-compose.yml
docker-compose up -d

# For LXC configs:
op inject -i configs/netbird.template.yml -o /tmp/netbird.yml
scp /tmp/netbird.yml root@lxc3:/etc/netbird/config.yml
systemctl restart netbird
```

**CI/CD Integration**:
- GitHub runner authenticates with 1Password Service Account
- Workflows inject secrets during build/deploy steps
- GitHub repository secrets store 1Password service account token

**Critical Secrets Managed**:
- Database credentials (PostgreSQL, MongoDB, Redis)
- API keys (OpenAI, Telegram bot token)
- Service credentials (Netbird, Authentik OAuth clients)
- GitHub runner tokens
- SMTP credentials
- SSL certificates (Traefik)

**Benefits**:
- ✅ Single source of truth (1Password)
- ✅ Works everywhere (local, CI/CD, production)
- ✅ No additional infrastructure to maintain
- ✅ Secrets never in plain text on disk (except during injection)
- ✅ Easy rotation (update in 1Password → re-inject → redeploy)
- ✅ Templates in git show structure without exposing secrets
- ✅ Familiar syntax for developers

**Secret Rotation Process**:
1. Update secret in 1Password vault
2. Re-run `op inject` command
3. Restart affected services
4. Old secret immediately invalidated

### Updates & Maintenance Strategy

> **Status**: 🚧 IN PROGRESS - Decision #17

**TODO**: Define how to handle system updates, container updates, and security patches

**Areas to Cover**:
- LXC container updates (Debian/Ubuntu base systems)
- Docker container updates (image updates)
- Proxmox host updates
- Database updates (PostgreSQL, MongoDB, Redis)
- Security patches
- Update notification and automation
- Maintenance windows
- Rollback procedures

---

## Next Steps

### Completed (16/18 decisions)

- ✅ Reverse Proxy (Traefik)
- ✅ DNS & Ad Blocking (AdGuard Home)
- ✅ VPN (Netbird)
- ✅ AI Agent Core (n8n + OpenAI + Telegram) - moved to Docker
- ✅ SSO (Authentik)
- ✅ Database & Storage Services (PostgreSQL, MongoDB, Redis, MinIO)
- ✅ NAS (Xpenology)
- ✅ Docker Host (VM 3) - Media, Automation & AI
- ✅ Coolify (VM 4) - Web Apps
- ✅ Observability & Monitoring (Grafana + Prometheus + Loki + Alloy agents)
- ✅ Dashboard (Homepage + Grafana)
- ✅ Git Hosting (GitHub)
- ✅ CI/CD Pipeline (GitHub self-hosted runners + Coolify)
- ✅ Secrets Management (1Password CLI)
- ✅ **Network Layout** (IP addressing, VLANs, firewall rules)
- ✅ **Storage Organization** (Xpenology folder structure, storage strategy)
- ✅ **Docker Volume Strategy** (mount paths, bind mounts, database connections)

### Pending (2/18 decisions)

1. **Decision #12**: Backup Strategy (what, how, where, when)
2. **Decision #17**: Updates & Maintenance Strategy (system updates, container updates, security patches)

---

## Change Log

- **2025-01-XX**: Initial documentation created
- **2025-01-XX**: Moved to infrastructure-as-code repository

---

**Repository**: `/Repositories/infrastructure`
**Maintained by**: [Your Name]
**Last Updated**: 2025-01-XX
