# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working Philosophy

**Progressive Development**: Build incrementally, one service at a time. No large dumps of information or code.

**User Control**: Present information, get decisions, implement. User stays in control.

**Documentation Style**:
- Concise, actionable commands only
- No stories or lengthy explanations
- Format: "Do X: `command` - brief what it does"
- Update decisions in code and docs as we go
- Keep it simple, secure, functional

**Decision Tracking**: When decisions are made during implementation:
1. Update affected code immediately
2. Update relevant documentation sections
3. No over-engineering - simple solutions first

## Repository Overview

This is a homelab infrastructure repository for managing Docker-based services across multiple Proxmox VMs. The architecture uses VirtioFS to mount subdirectories from a central git repository on the Proxmox host to individual VMs, making all VMs stateless and disposable.

**Key Principle**: All work happens inside `/opt/homelab` on each VM, which is mounted via VirtioFS from `/flash/docker/homelab/<vm-name>` on the Proxmox host.

## Architecture

### VM Layout

| VM | IP | Directory | Services |
|----|-----|-----------|----------|
| db | 10.10.10.111 | `/opt/homelab` (→ `db/`) | MongoDB, PostgreSQL, Redis, MinIO |
| observability | 10.10.10.112 | `/opt/homelab` (→ `observability/`) | Komodo, Prometheus, Grafana, Loki |
| edge | 10.10.10.110 | `/opt/homelab` (→ `edge/`) | Traefik, AdGuard, Authentik |
| media | 10.10.10.113 | `/opt/homelab` (→ `media/`) | Jellyfin, Arr Stack, n8n, Paperless |
| coolify | 10.10.10.114 | Custom install | Coolify PaaS |

### Deployment Strategy

Services are deployed progressively in dependency order:
1. **Phase 1**: MongoDB (required by Komodo) → Komodo (management UI)
2. **Phase 2**: PostgreSQL, Redis, MinIO → Traefik → AdGuard → Authentik
3. **Phase 3**: Prometheus → Grafana → Loki → Alloy
4. **Phase 4**: Media services, n8n, Paperless, Coolify

## Common Commands

### Deploying Services

All services use 1Password for secrets management. The pattern is:
```bash
# Deploy a service
op run --env-file=.env -- docker compose up -d <service-name>

# Deploy multiple services
op run --env-file=.env -- docker compose up -d service1 service2

# Deploy all services in a compose file
op run --env-file=.env -- docker compose up -d
```

### Komodo Periphery Setup

Install Periphery agent on each VM to allow Komodo management:
```bash
# Install Periphery as systemd service
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | sudo python3

# Enable on boot
sudo systemctl enable periphery

# Check status
sudo systemctl status periphery
```

Then add server in Komodo UI with address: `http://<vm-ip>:8120`

### Checking Status

```bash
# Check running containers
docker compose ps

# View logs (follow mode)
docker compose logs -f <service-name>

# Check specific service health
docker compose exec <service-name> <health-command>
```

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new config/images
op run --env-file=.env -- docker compose up -d

# Update specific service
docker compose pull <service-name>
op run --env-file=.env -- docker compose up -d <service-name>
```

### Completely Removing and Reinstalling a Service

```bash
# Stop and remove container + named volumes
docker compose down <service-name> -v

# Remove bind mount data (./service/data directories)
sudo rm -rf <service-name>/data/*

# Remove from database if service uses one
# MongoDB example (for Komodo):
docker exec -it mongodb mongosh --host 10.10.10.111:27017 -u <user> -p <pass> --authenticationDatabase admin --eval "use <dbname>; db.dropDatabase();"

# PostgreSQL example (for Authentik):
docker exec -it postgres psql -U postgres -c "DROP DATABASE <dbname>;"

# Redeploy fresh
docker compose pull <service-name>
op run --env-file=.env -- docker compose up -d <service-name>

# Clean up dangling resources
docker system prune -f
```

**Note:** `docker compose down -v` removes named volumes but does NOT delete bind mount directories. You must manually remove bind mount data.

### Testing Database Connections

```bash
# MongoDB (from db host)
docker exec mongodb mongosh --eval "db.adminCommand('ping')"

# PostgreSQL (from db host)
docker exec postgres pg_isready -U postgres

# Test from another VM
mongosh --host 10.10.10.111:27017 -u <user> -p <pass>
psql -h 10.10.10.111 -U <user> -d <database>
```

## Important Patterns

### 1Password Integration

All `.env` files contain only 1Password references (not actual secrets):
```bash
# .env file (safe to commit)
MONGODB_ROOT_USER=op://Server/mongodb/username
MONGODB_ROOT_PASSWORD=op://Server/mongodb/password
```

The `op run --env-file=.env` command fetches secrets at runtime. Never commit actual passwords.

### VirtioFS Workflow

Changes to configuration files follow this pattern:
1. Edit files on Proxmox host: `/flash/docker/homelab/<vm-name>/`
2. Commit changes: `git commit` and `git push`
3. Changes are immediately visible on all VMs (no git pull needed)
4. Restart affected services on each VM

### Service Dependencies

All services connect to centralized databases on the db host:
```yaml
# PostgreSQL connection format
DATABASE_URL: postgresql://user:pass@10.10.10.111:5432/dbname

# MongoDB connection format
MONGO_URL: mongodb://user:pass@10.10.10.111:27017/dbname

# Redis connection format
REDIS_URL: redis://10.10.10.111:6379/0

# MinIO connection format
S3_ENDPOINT: http://10.10.10.111:9000
```

### Progressive Service Deployment

When enabling new services:
1. Uncomment the service in `docker-compose.yml`
2. Uncomment corresponding env vars in `.env`
3. Ensure dependencies are running (check the dependency tree in README.md)
4. Deploy with `op run --env-file=.env -- docker compose up -d <service-name>`

## Directory Structure

**Standardized Layout** - All VMs follow this pattern:

```
{vm-name}/
├── docker-compose.yml
├── .env                        # 1Password references only
├── {service-name}/
│   ├── config/                 # Service configs (committed)
│   ├── certs/                  # TLS certs (gitignored)
│   └── data/                   # Runtime data (gitignored)
```

**Example:**

```
infrastructure/
├── db/
│   ├── docker-compose.yml
│   ├── .env
│   ├── mongodb/
│   │   ├── config/mongod.conf
│   │   ├── certs/
│   │   └── data/
│   ├── postgres/
│   │   ├── config/
│   │   ├── certs/
│   │   └── data/
│   ├── redis/
│   │   ├── certs/
│   │   └── data/
│   └── minio/
│       ├── certs/
│       └── data/
│
├── observability/
│   ├── docker-compose.yml
│   ├── .env
│   ├── komodo/data/
│   ├── prometheus/
│   │   ├── config/
│   │   └── data/
│   ├── grafana/
│   │   ├── provisioning/
│   │   └── data/
│   ├── loki/
│   │   ├── config/
│   │   └── data/
│   └── alloy/config/
│
├── edge/
│   ├── docker-compose.yml
│   ├── .env
│   ├── traefik/
│   │   ├── config/
│   │   └── data/
│   ├── adguard/data/
│   └── authentik/
│       ├── certs/
│       └── data/
│
├── media/
│   ├── docker-compose.yml
│   ├── .env
│   ├── jellyfin/data/
│   ├── prowlarr/data/
│   ├── sonarr/data/
│   ├── radarr/data/
│   ├── qbittorrent/data/
│   ├── n8n/data/
│   └── paperless/data/
│
└── coolify/
    └── README.md
```

## Key Configuration Files

### Database Configurations

- `db/mongodb/config/mongod.conf` - MongoDB config (TLS, replication)
- `db/postgres/config/postgresql.conf` - PostgreSQL tuning
- `db/postgres/config/pg_hba.conf` - PostgreSQL access control

### Monitoring Configurations

- `observability/prometheus/config/prometheus.yml` - Scrape configs
- `observability/prometheus/config/rules/alerts.yml` - Alerting rules
- `observability/grafana/provisioning/` - Datasources, dashboards
- `observability/loki/config/config.yml` - Loki with MinIO backend
- `observability/alloy/config/config.alloy` - Metrics/logs collection

### Edge Configurations

- `edge/traefik/config/traefik.yml` - Traefik entrypoints, SSL
- `edge/traefik/config/dynamic/authentik.yml` - Authentik forward auth

## Troubleshooting

### VirtioFS Mount Issues
```bash
# Check if mounted
mount | grep virtiofs

# Remount manually
sudo mount -a

# Check fstab
cat /etc/fstab | grep docker-vm
```

### 1Password Issues
```bash
# Verify token is set
echo $OP_SERVICE_ACCOUNT_TOKEN

# Test connection
op vault list

# Test secret retrieval
op read "op://Server/mongodb/username"
```

### Container Issues
```bash
# Check if port already in use
sudo netstat -tulpn | grep <port>

# Check container logs
docker compose logs --tail=50 <service-name>

# Verify secrets loaded correctly (debug only, careful with sensitive data)
op run --env-file=.env -- env | grep -i password
```

### Network Connectivity
```bash
# Test database connectivity from another VM
nc -zv 10.10.10.111 27017    # MongoDB
nc -zv 10.10.10.111 5432     # PostgreSQL
nc -zv 10.10.10.111 6379     # Redis
```

## Working with This Repository

### Making Changes to Configuration

1. SSH to Proxmox host
2. Navigate to `/flash/docker/homelab`
3. Make changes to files
4. Commit and push: `git add . && git commit -m "message" && git push`
5. Changes are immediately visible on VMs via VirtioFS
6. SSH to affected VM and restart services

### Adding a New Service

1. Add service definition to appropriate `docker-compose.yml`
2. Add required env vars to `.env` file (using `op://` references)
3. Create 1Password entries if needed
4. Add any config files to `config/` directory
5. Test deploy: `op run --env-file=.env -- docker compose up -d <service-name>`
6. Check logs: `docker compose logs -f <service-name>`
7. Commit changes

### Creating a New VM

Follow the detailed steps in `VM-TEMPLATE-SETUP.md`. Key points:
1. Clone from template (full clone recommended)
2. Set static IP in Proxmox
3. Add VirtioFS mount pointing to subdirectory: `qm set <vm-id> --virtfs0 /flash/docker/homelab/<vm-name>,mp=docker-vm`
4. Boot VM and configure hostname
5. Mount VirtioFS: `sudo mount -t virtiofs docker-vm /opt/homelab`
6. Set `OP_SERVICE_ACCOUNT_TOKEN` in `~/.bashrc`
7. Navigate to `/opt/homelab` and deploy services

## Security Notes

- All secrets stored in 1Password (vault: "Server")
- `.env` files are safe to commit (contain only `op://` references)
- Never commit actual passwords or tokens
- Each VM should have its own SSH key for git (or use same key, copied after cloning)
- TLS certificates auto-generated in `certs/` directories (gitignored)

## Network Information

- VLAN 10 (10.10.10.0/24): Homelab services
- Gateway: 10.10.10.1
- DNS: AdGuard Home on 10.10.10.110
- All VMs communicate over VLAN 10
