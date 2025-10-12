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

> **Status**: 🚧 IN PROGRESS - Decision #13

<!-- TODO: Complete network design documentation -->

### IP Addressing Scheme

**TODO**: Define static IP allocations for all services

```
Planned Subnets:
- Management VLAN: [TODO]
- Infrastructure VLAN: [TODO]
- Database Tier VLAN: [TODO] (isolated)
- Docker Network: [TODO]
- IoT VLAN: [TODO]
```

### Firewall Rules

**TODO**: Document firewall rules between network segments

Key Requirements:
- Database tier (LXC 5, 6, 7) must have strict firewall rules
- Only authorized services can access database ports
- IoT devices isolated from main network

### DNS Configuration

**TODO**: DNS record structure for internal services

```
Examples:
- traefik.homelab.local → [IP]
- plex.homelab.local → [IP]
- nas.homelab.local → [IP]
```

---

## Storage Organization

> **Status**: 🚧 IN PROGRESS - Decision #10

<!-- TODO: Complete storage organization documentation -->

### Xpenology Folder Structure

**TODO**: Define complete NAS folder hierarchy

```
Planned Structure:
/volume1/
  ├── media/
  │   ├── movies/
  │   ├── tv/
  │   ├── music/
  │   └── books/
  ├── backups/
  │   ├── databases/
  │   ├── docker-configs/
  │   └── proxmox-dumps/
  ├── docker/
  └── iso/
```

### Docker Volume Strategy

**TODO**: Define Docker volume management approach - Decision #11

Questions to answer:
- Exact volume mount paths
- Bind mounts vs named volumes
- How containers access database tier (connection strings, not volumes)
- Portainer volume management strategy

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

### Completed (12/18 decisions)

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

### Pending (6/18 decisions)

1. **Decision #10**: Storage Organization (Xpenology folder structure)
2. **Decision #11**: Docker Volume Strategy (mount paths, volume types)
3. **Decision #12**: Backup Strategy (what, how, where, when)
4. **Decision #13**: Network Layout (IP addressing, VLANs, firewall rules)
5. **Decision #17**: Updates & Maintenance Strategy (system updates, container updates, security patches)
6. **Decision #18**: Notification & Alerting System (alert sources, routing, channels, severity logic)

---

## Change Log

- **2025-01-XX**: Initial documentation created
- **2025-01-XX**: Moved to infrastructure-as-code repository

---

**Repository**: `/Repositories/infrastructure`
**Maintained by**: [Your Name]
**Last Updated**: 2025-01-XX
