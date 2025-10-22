# Infrastructure Progress & Notes

**Single source of truth for homelab build progress and quick reference notes.**

---

## Current Progress

### Phase 1: Foundation ✅ DONE
- [x] MongoDB (db host - 10.10.10.111)
- [x] PostgreSQL (db host - 10.10.10.111)
- [x] Redis (db host - 10.10.10.111)
- [x] MinIO (db host - 10.10.10.111)
- [x] Portainer (observability host - 10.10.10.112)

### Phase 2: Edge Services ✅ COMPLETE
- [x] Traefik (edge host - 10.10.10.110) - Deployed, SSL working
- [x] AdGuard Home (edge host - 10.10.10.110) - Deployed, DNS rewrites configured
- [x] Authentik SSO (edge host - 10.10.10.110) - Deployed, admin account: akadmin

### Phase 3: Observability ⏳ PENDING
- [ ] Prometheus (observability host - 10.10.10.112)
- [ ] Grafana (observability host - 10.10.10.112)
- [ ] Loki (observability host - 10.10.10.112)
- [ ] Alloy (observability host - 10.10.10.112)

### Phase 4: Applications ⏳ PENDING
- [ ] Jellyfin, Arr Stack, qBittorrent (media host - 10.10.10.113)
- [ ] n8n, Paperless (media host - 10.10.10.113)
- [ ] Coolify (coolify host - 10.10.10.114)

---

## Quick Reference Notes

### 🔴 CRITICAL: Always Use Existing Infrastructure Services

**NEVER deploy separate databases or services when we already have them!**

**Use these existing services from db host (10.10.10.111):**
- **PostgreSQL** - For any app needing SQL database
- **MongoDB** - For any app needing NoSQL/document database
- **Redis** - For caching, sessions, queues
- **MinIO** - For object storage (S3-compatible)

**How to connect:**
```yaml
# PostgreSQL
DATABASE_URL: postgresql://username:password@10.10.10.111:5432/dbname

# MongoDB
MONGO_URL: mongodb://username:password@10.10.10.111:27017/dbname

# Redis
REDIS_URL: redis://:password@10.10.10.111:6379/0

# MinIO (S3)
S3_ENDPOINT: http://10.10.10.111:9000
AWS_ACCESS_KEY_ID: (from 1Password)
AWS_SECRET_ACCESS_KEY: (from 1Password)
```

**For new apps:**
1. Check if app needs database → use PostgreSQL or MongoDB
2. Check if app needs caching → use Redis
3. Check if app needs file storage → use MinIO
4. Create database/user on db host if needed
5. Add credentials to 1Password
6. Configure app to use existing service

**Benefits:**
- ✅ Centralized backup and maintenance
- ✅ Lower resource usage
- ✅ Consistent connection patterns
- ✅ Single source of truth for data

---

### Traefik (Reverse Proxy)

**Config Structure:**
```
edge/traefik/config/dynamic/
├── middlewares.yml  - Auth, headers, rate limiting, compression
├── services.yml     - Backend targets (IP:port)
└── routers.yml      - Domain routing rules
```

**To add a new service:**
1. Add service in `services.yml`:
   ```yaml
   myapp:
     loadBalancer:
       servers:
         - url: "http://10.10.10.x:port"
   ```

2. Add router in `routers.yml`:
   ```yaml
   myapp:
     rule: "Host(`myapp.onurx.com`)"
     entryPoints: [websecure]
     service: myapp
     middlewares: [authentik, security-headers]  # Optional
     tls:
       certResolver: cloudflare
   ```

3. (Optional) Add middleware in `middlewares.yml` if custom processing needed

**Auto-reload:** Traefik reloads dynamic configs automatically (no restart)

**Dashboard:** `http://10.10.10.110:8080`

**SSL Certs:** Cloudflare DNS-01 challenge, stored in `/data/acme.json`

---

### AdGuard Home (DNS)

**Status:** Ready to deploy

**Purpose:** Internal DNS resolution for `*.onurx.com` domains

**Config:** `edge/adguard/data/conf/AdGuardHome.yaml`

**Deploy:**
```bash
# On edge VM (10.10.10.110)
cd /opt/homelab
docker compose up -d adguard

# Check logs
docker compose logs -f adguard

# Access web UI
http://10.10.10.110:8888
```

**Initial Setup:**
1. Access `http://10.10.10.110:3000` on first run
2. Create admin account (username: admin)
3. Skip other setup steps (config already done)
4. Access main UI at `http://10.10.10.110:8888`

**DNS Rewrites (Pre-configured):**
All `*.onurx.com` domains → `10.10.10.110`:
- auth, portainer, grafana, sonarr, radarr, prowlarr
- jellyfin, qbittorrent, n8n, paperless, coolify
- minio, s3

**After Deployment:**
1. Update router DNS to `10.10.10.110`
2. Test: `nslookup grafana.onurx.com` should return `10.10.10.110`
3. Test SSL: `https://grafana.onurx.com` should work with valid cert

**Why AdGuard?**
- Config-as-code (YAML file in git)
- DNS rewrites pre-configured
- Modern, actively developed
- Fits infrastructure-as-code workflow

---

### Authentik (SSO)

**Status:** Ready to deploy

**Dependencies:** PostgreSQL + Redis on db host (10.10.10.111)

**Access:** `https://auth.onurx.com` (via Traefik)

## Pre-Deployment: Setup 1Password Secrets

**Create these items in 1Password "Server" vault:**

1. **authentik-db** (PostgreSQL user password)
   - Field: `password` (generate strong password)

2. **authentik** (Authentik secret key)
   - Field: `secret_key` (generate with: `openssl rand -base64 50`)

**Verify secrets:**
```bash
op read "op://Server/redis/password"
op read "op://Server/authentik-db/password"
op read "op://Server/authentik/secret_key"
```

## Pre-Deployment: Create PostgreSQL Database

**On db host (10.10.10.111):**
```bash
# SSH to db host
ssh root@10.10.10.111
cd /opt/homelab

# Create database and user
docker exec -it postgres psql -U postgres
```

**In PostgreSQL shell:**
```sql
-- Create user
CREATE USER authentik WITH PASSWORD 'paste_password_from_1password_here';

-- Create database
CREATE DATABASE authentik OWNER authentik;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

-- Exit
\q
```

**Test connection from edge VM:**
```bash
# On edge VM (10.10.10.110)
psql -h 10.10.10.111 -U authentik -d authentik
# Enter password from 1Password
# Should connect successfully
```

## Deployment

**On edge VM (10.10.10.110):**
```bash
cd /opt/homelab

# Deploy Authentik (server + worker)
op run --env-file=.env -- docker compose up -d authentik-server authentik-worker

# Check logs
docker compose logs -f authentik-server
docker compose logs -f authentik-worker

# Should see:
# - Database migrations running
# - Worker starting
# - Server ready
```

## Initial Setup

**Access:** `https://auth.onurx.com`

**First-time setup wizard:**
1. Create admin account (email + password)
2. Complete setup

**After setup:**
- Configure outpost for Traefik forward auth
- Create applications for each service
- Configure authentication flows

## Protected Services

Services using `authentik` middleware (configured in `routers.yml`):
- grafana, sonarr, radarr, prowlarr, jellyfin
- qbittorrent, n8n, paperless, coolify
- minio console

**Not protected:**
- Authentik itself (auth.onurx.com) - no self-auth
- Portainer - has own auth
- MinIO S3 API (s3.onurx.com) - programmatic access

## Troubleshooting

**Database connection errors:**
```bash
# Verify database exists on db host
docker exec -it postgres psql -U postgres -c "\l" | grep authentik

# Test connection from edge VM
psql -h 10.10.10.111 -U authentik -d authentik
```

**Redis connection errors:**
```bash
# Test Redis from edge VM
docker run --rm redis:alpine redis-cli -h 10.10.10.111 -a $(op read "op://Server/redis/password") ping
# Should return: PONG
```

---

### Database Connections

All services connect to db host (10.10.10.111):

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

### VirtioFS Workflow

**All VMs mount subdirectories from Proxmox host:**

Proxmox: `/flash/docker/homelab/<vm-name>/`
VM: `/opt/homelab/` (mounted via VirtioFS)

**To update configs:**
1. Edit files on Proxmox: `cd /flash/docker/homelab`
2. Commit changes: `git add . && git commit && git push`
3. Changes immediately visible on VMs (no git pull needed)
4. Restart affected services: `op run --env-file=.env -- docker compose up -d <service>`

---

## Common Commands

### Deploy Service
```bash
# SSH to VM
ssh root@10.10.10.xxx

# Navigate to working dir
cd /opt/homelab

# Deploy single service
op run --env-file=.env -- docker compose up -d <service-name>

# Deploy all services
op run --env-file=.env -- docker compose up -d

# Check logs
docker compose logs -f <service-name>
```

### Check Status
```bash
# Container status
docker compose ps

# View logs
docker compose logs -f <service-name>

# Traefik dashboard
http://10.10.10.110:8080

# Portainer
https://10.10.10.112:9443
```

### Update Service
```bash
# Pull latest image
docker compose pull <service-name>

# Recreate container
op run --env-file=.env -- docker compose up -d <service-name>
```

### Remove and Reinstall Service
```bash
# Stop and remove
docker compose down <service-name> -v

# Remove bind mount data
rm -rf <service-name>/data/*

# Redeploy
docker compose pull <service-name>
op run --env-file=.env -- docker compose up -d <service-name>
```

### Test Database Connections
```bash
# MongoDB (from db host)
docker exec mongodb mongosh --eval "db.adminCommand('ping')"

# PostgreSQL (from db host)
docker exec postgres pg_isready -U postgres

# Test from another VM
mongosh --host 10.10.10.111:27017 -u <user> -p <pass>
psql -h 10.10.10.111 -U <user> -d <database>
```

### Create New VM
```bash
# On Proxmox host
qm clone <template-id> <new-id> --name <vm-name> --full
qm set <new-id> --memory 4096 --cores 2 --ipconfig0 ip=10.10.10.xxx/24,gw=10.10.10.1
qm set <new-id> --virtfs0 /flash/docker/homelab/<vm-name>,mp=docker-vm
qm start <new-id>

# Inside VM
hostnamectl set-hostname <vm-name>
mkdir -p /opt/homelab
mount -t virtiofs docker-vm /opt/homelab
echo 'docker-vm /opt/homelab virtiofs defaults 0 0' >> /etc/fstab
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_xxx"' >> ~/.bashrc
source ~/.bashrc
cd /opt/homelab
```

---

## VM Template Setup

### Create Template (One-Time)

**Install base packages:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y curl wget vim htop net-tools git ca-certificates gnupg

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker homelab
sudo systemctl enable docker

# Configure Git (this is saved in template)
git config --global user.name "XVll"
git config --global user.email "onur03@gmail.com"

# Install 1Password CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install -y 1password-cli

# Install QEMU guest agent
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
```

**Clean before templating:**
```bash
# Remove SSH keys (regenerated on boot)
sudo rm -f /etc/ssh/ssh_host_*

# Clear history and machine-id
cat /dev/null > ~/.bash_history
history -c
sudo truncate -s 0 /etc/machine-id

# Shutdown
sudo shutdown -h now
```

**Convert to template in Proxmox UI:** Right-click VM → Convert to Template

**Important:**
- Git is pre-configured in template (name/email)
- DO NOT set `OP_SERVICE_ACCOUNT_TOKEN` in template (set per VM)
- Use Full Clone when creating VMs (not Linked Clone)

---

## 1Password Setup

### Create Items in "Server" Vault

**Required items:**
- `mongodb` - fields: username, password
- `postgres` - fields: username, password
- `redis` - field: password
- `minio` - fields: username, password
- `grafana` - fields: username, password
- `cloudflare` - fields: email, api_token
- `authentik-db` - field: password (PostgreSQL user password)
- `authentik` - field: secret_key (generate with: `openssl rand -base64 50`)

**Verify setup:**
```bash
op read "op://Server/mongodb/username"
op read "op://Server/postgres/password"
```

**How it works:**
1. `.env` files contain: `MONGODB_ROOT_USER=op://Server/mongodb/username`
2. Run: `op run --env-file=.env -- docker compose up -d`
3. `op run` fetches actual values from 1Password and injects them

**Troubleshooting:**
- "item not found" → Check vault name is "Server", item/field names match exactly
- "not signed in" → Set `OP_SERVICE_ACCOUNT_TOKEN` in `~/.bashrc`

---

## Service-Specific Notes

### Coolify (PaaS)

**Status:** Not deployed yet

**Installation:**
```bash
# SSH to coolify VM (10.10.10.114)
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

**Access:** `http://10.10.10.114:8000` or `https://coolify.onurx.com`

**Use external databases:**
```
DATABASE_URL=postgresql://app:pass@10.10.10.111:5432/app
REDIS_URL=redis://:pass@10.10.10.111:6379
MONGODB_URL=mongodb://app:pass@10.10.10.111:27017/app
```

**Deployment:** git push → automatic build & deploy

**Not managed by docker-compose** - uses own installer

---

## Network Layout

| VM | IP | Services |
|----|-----|----------|
| db | 10.10.10.111 | MongoDB, PostgreSQL, Redis, MinIO |
| observability | 10.10.10.112 | Portainer, Prometheus, Grafana, Loki, Alloy |
| edge | 10.10.10.110 | Traefik, AdGuard, Authentik |
| media | 10.10.10.113 | Jellyfin, Arr Stack, n8n, Paperless, qBittorrent |
| coolify | 10.10.10.114 | Coolify PaaS |

**Network:** VLAN 10 (10.10.10.0/24)
**Gateway:** 10.10.10.1
**DNS (after AdGuard):** 10.10.10.110

---

## Important Notes

### Secrets Management
- All passwords in 1Password (vault: "Server")
- `.env` files contain only `op://` references (safe to commit)
- Never commit actual passwords
- Use `op run --env-file=.env -- <command>` to inject secrets

### Service Dependencies
Deploy in order:
1. Databases (MongoDB, PostgreSQL, Redis, MinIO)
2. Portainer (for management)
3. Traefik → AdGuard → Authentik
4. Observability stack
5. Applications

### Traefik SSL
- Domain: `*.onurx.com`
- Provider: Cloudflare DNS-01 challenge
- Email: onur03@gmail.com
- Certs stored: `edge/traefik/data/acme.json`
- Auto-renewal via Let's Encrypt

### File Naming Convention
- `@file` - Defined in YAML files (what we use)
- `@docker` - Defined via Docker labels
- `@internal` - Traefik built-ins

---

## Next Steps

### Current Status
- ✅ **Phase 1 COMPLETE**: Databases (MongoDB, PostgreSQL, Redis, MinIO) + Portainer
- ✅ **Phase 2 COMPLETE**: Traefik + AdGuard + Authentik
  - Traefik reverse proxy with SSL (Cloudflare DNS-01)
  - AdGuard Home DNS server deployed
  - Authentik SSO with embedded outpost configured
  - Forward auth middleware ready (uses `authentik` middleware in routers.yml)
  - Admin user: `akadmin` (login: http://10.10.10.110:9000)
- ⏳ **Phase 3 PENDING**: Observability Stack (Prometheus, Grafana, Loki, Alloy)
- ⏳ **Phase 4 PENDING**: Applications (Jellyfin, Arr Stack, n8n, Paperless, Coolify)

### Immediate Next Tasks

**1. Deploy Observability Stack** (observability VM - 10.10.10.112)
   - Prometheus (metrics collection)
   - Grafana (dashboards + visualization)
   - Loki (log aggregation)
   - Alloy (metrics/logs collector)

**2. Deploy Media Services** (media VM - 10.10.10.113)
   - Jellyfin (media server)
   - Prowlarr → Sonarr/Radarr (media management)
   - qBittorrent (download client)
   - n8n (workflow automation)
   - Paperless (document management)

**3. Deploy Coolify** (coolify VM - 10.10.10.114)
   - Self-hosted PaaS platform

**4. Cutover from Old Infrastructure**
   - Update DNS to point to new infrastructure
   - Test all services end-to-end
   - Verify Authentik forward auth works
   - Decommission old infrastructure

### Important Notes
- **Authentik Forward Auth**: Uses embedded outpost (no separate container needed)
- **Forward Auth Endpoint**: `http://authentik-server:9000/outpost.goauthentik.io/auth/traefik`
- **Protected Services**: Add `authentik` middleware to router in `routers.yml`
- **DNS rewrites**: Managed via AdGuard UI at http://10.10.10.110:8888
- **Testing**: Will test when switching from old to new infrastructure

---

**Last Updated:** 2025-10-21
