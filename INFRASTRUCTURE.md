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

### Phase 2: Edge Services 🚧 IN PROGRESS
- [x] Traefik (edge host - 10.10.10.110) - Deployed, SSL working
- [ ] AdGuard Home (edge host - 10.10.10.110) - NEXT
- [ ] Authentik SSO (edge host - 10.10.10.110) - After AdGuard

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

**Status:** Not deployed yet

**Purpose:** Internal DNS resolution for `*.onurx.com` domains

**Setup:**
1. Deploy: `op run --env-file=.env -- docker compose up -d adguard`
2. Access: `http://10.10.10.110:3000` (initial setup)
3. Add DNS rewrites for all services (see below)
4. Update router DNS to `10.10.10.110`

**DNS Rewrites to Configure:**
Map all `*.onurx.com` domains to `10.10.10.110`:
- auth.onurx.com → 10.10.10.110
- portainer.onurx.com → 10.10.10.110
- grafana.onurx.com → 10.10.10.110
- sonarr.onurx.com → 10.10.10.110
- radarr.onurx.com → 10.10.10.110
- prowlarr.onurx.com → 10.10.10.110
- jellyfin.onurx.com → 10.10.10.110
- qbittorrent.onurx.com → 10.10.10.110
- n8n.onurx.com → 10.10.10.110
- paperless.onurx.com → 10.10.10.110
- coolify.onurx.com → 10.10.10.110
- minio.onurx.com → 10.10.10.110
- s3.onurx.com → 10.10.10.110

**Why this approach?**
- Valid SSL certs from Let's Encrypt (no browser warnings)
- Internal-only access (not exposed to internet)
- Simple domain names instead of `.homelab.local`

---

### Authentik (SSO)

**Status:** Not deployed yet

**Dependencies:** PostgreSQL + Redis on db host (10.10.10.111)

**Deploy After:** AdGuard (so DNS resolution works)

**Protected Services:** All services use `authentik` middleware except:
- Authentik itself (auth.onurx.com) - no self-auth
- Portainer - has own auth
- MinIO S3 API (s3.onurx.com) - programmatic access

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

1. **Deploy AdGuard Home** (edge VM)
   - Uncomment service in `edge/docker-compose.yml`
   - Deploy and configure DNS rewrites
   - Update router DNS

2. **Deploy Authentik** (edge VM)
   - Requires AdGuard DNS working
   - Create databases on db host
   - Configure forward auth

3. **Deploy Observability Stack** (observability VM)
   - Prometheus → Grafana → Loki → Alloy
   - Configure dashboards

4. **Deploy Media Services** (media VM)
   - Jellyfin → Prowlarr → Sonarr/Radarr → qBittorrent
   - n8n and Paperless

---

**Last Updated:** 2025-10-21
