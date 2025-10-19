# Infrastructure Quick Start Guide

Progressive deployment - build piece by piece, test as you go.

## Prerequisites

### On Your Local Machine
1. **1Password CLI** - `brew install 1password-cli`
2. **Service Account Token** - `export OP_SERVICE_ACCOUNT_TOKEN="ops_..."`

### On Each VM
1. **VMs created** in Proxmox from template (see [VM-TEMPLATE-SETUP.md](./VM-TEMPLATE-SETUP.md))
2. **NAS running** at 10.10.10.115

Or if not using template:
3. **Docker installed** - `curl -fsSL https://get.docker.com | sh`
4. **Git configured** - `git config --global user.name "Homelab" && git config --global user.email "homelab@local"`

## Progressive Deployment Order

Deploy in this order from most to least important:

### 1️⃣ Komodo (5 min) - Monitor Everything

**Why first:** See all containers as you build them!

```bash
# SSH to observability VM (10.10.10.112)

# If private repo, set up SSH key first:
ssh-keygen -t ed25519 -C "homelab-observability" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub  # Add this to GitHub/GitLab

# Clone repository (git already configured if using template!)
cd /opt
git clone git@github.com:yourusername/infrastructure-1.git homelab
cd homelab/observability

# Deploy Komodo
docker compose up -d
```

✅ **Access:** http://10.10.10.112:9120

Now you can watch all deployments in real-time!

---

### 2️⃣ PostgreSQL (10 min) - Core Database

**Why second:** Everything needs a database!

```bash
# SSH to data VM (10.10.10.111)

# If private repo, set up SSH key first:
ssh-keygen -t ed25519 -C "homelab-data" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub  # Add this to GitHub/GitLab

# Clone repository (git already configured if using template!)
cd /opt
git clone git@github.com:yourusername/infrastructure-1.git homelab
cd homelab/data

# Generate PostgreSQL certificates
cd certs/postgres
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key -subj "/CN=Homelab CA"
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key -subj "/CN=postgres.homelab.local"
chmod 600 server.key ca.key
chmod 644 server.crt ca.crt
cd ../..

# Create 1Password secret
op item create --category=database --title=postgres \
  --vault=Server username=postgres password=$(openssl rand -base64 32)

# Deploy (the .env file already has 1Password references)
op run --env-file=.env -- docker compose up -d
```

✅ **Test:** `docker exec -it postgres psql -U postgres`
✅ **Watch in Komodo:** See it appear!

---

### 3️⃣ Traefik (15 min) - Reverse Proxy

**Why third:** Routes all HTTP/HTTPS traffic!

```bash
# SSH to edge VM (10.10.10.110)

# Clone repository (git already configured if using template!)
cd /opt
git clone <repo-url> homelab
cd homelab/edge

# Create 1Password secret for Cloudflare
op item create --category=login --title=cloudflare \
  --vault=Server \
  email=your@email.com \
  api_token=your-cloudflare-api-token

# Update email in config/traefik/traefik.yml

# Create acme.json
touch data/traefik/acme.json
chmod 600 data/traefik/acme.json

# Deploy (the .env file already has 1Password references)
op run --env-file=.env -- docker compose up -d
```

✅ **Access Dashboard:** http://10.10.10.110:8080
✅ **Watch in Komodo:** See Traefik running

---

### 4️⃣ Jellyfin (Optional - 10 min) - Media Server

**Why fourth:** Entertainment! (optional but fun)

```bash
# SSH to media VM (10.10.10.113)

# Clone repository (git already configured if using template!)
cd /opt
git clone <repo-url> homelab
cd homelab/media

# Mount NAS media
sudo mkdir -p /mnt/nas/media
echo "10.10.10.115:/volume1/media /mnt/nas/media nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Deploy (no secrets needed for Jellyfin)
docker compose up -d
```

✅ **Access:** http://10.10.10.113:8096
✅ **Or via Traefik:** https://jellyfin.homelab.example.com

---

### 5️⃣ Add More Services As Needed

**Observability (Grafana, Prometheus):**
- See `observability/docker-compose.full.yml`
- Copy services you want to `docker-compose.yml`
- Deploy: `docker compose up -d`

**Data (MongoDB, Redis, MinIO):**
- See `data/PROGRESSIVE-SETUP.md`
- Add databases as needed
- Update `.env` with 1Password references
- Deploy: `op run --env-file=.env -- docker compose up -d`

**Edge (AdGuard, Authentik):**
- See `edge/PROGRESSIVE-SETUP.md`
- Add when you need DNS/SSO
- Update `.env` with 1Password references
- Deploy: `op run --env-file=.env -- docker compose up -d`

**Media (Arr Stack, n8n):**
- See `media/docker-compose.full.yml`
- Add automation when ready
- Deploy: `docker compose up -d`

**Coolify (PaaS):**
- See `coolify/README.md`
- Install when you want to deploy web apps

---

## Deployment Summary

| Priority | VM | Service | Time | Why |
|----------|-----|---------|------|-----|
| 🥇 **1** | observability | Komodo | 5 min | Monitor everything |
| 🥈 **2** | data | PostgreSQL | 10 min | Core database |
| 🥉 **3** | edge | Traefik | 15 min | Routing & SSL |
| 4️⃣ | media | Jellyfin | 10 min | Media (optional) |
| 5️⃣ | observability | Grafana | Later | Dashboards |
| 6️⃣ | data | MongoDB/Redis | Later | More databases |
| 7️⃣ | edge | AdGuard/Authentik | Later | DNS/SSO |
| 8️⃣ | media | Arr Stack | Later | Automation |
| 9️⃣ | coolify | Coolify | Later | Web apps |

**Total minimal setup time:** ~40 minutes

---

## Daily Workflow

### Via Komodo (Easiest)

1. Go to http://10.10.10.112:9120
2. See all containers
3. View logs, restart, manage - all from browser!

### Via Command Line

```bash
ssh data-vm
cd /opt/homelab/data
op run --env-file=.env -- docker compose ps                # Status
op run --env-file=.env -- docker compose logs -f postgres  # Logs
op run --env-file=.env -- docker compose restart postgres  # Restart
```

---

## Key Commands Reference

### 1Password

```bash
# Create secret
op item create --category=database --title=myapp \
  --vault=Server username=user password=$(openssl rand -base64 32)

# Read secret
op read "op://Server/postgres/password"

# List secrets
op item list --vault=Server
```

### Docker Compose (with 1Password)

```bash
op run --env-file=.env -- docker compose up -d           # Start
op run --env-file=.env -- docker compose down            # Stop
op run --env-file=.env -- docker compose logs -f         # View logs
op run --env-file=.env -- docker compose ps              # Status
op run --env-file=.env -- docker compose restart redis   # Restart service
op run --env-file=.env -- docker compose pull            # Update images
```

### Monitoring

- **Komodo:** http://10.10.10.112:9120
- **Traefik:** http://10.10.10.110:8080
- **Jellyfin:** http://10.10.10.113:8096

---

## Tips for Success

✅ **Start minimal** - Just 3 services to begin (Komodo, PostgreSQL, Traefik)
✅ **Use Komodo** - Monitor everything from one dashboard
✅ **Test each step** - Make sure it works before moving on
✅ **1Password for secrets** - Never commit passwords
✅ **Progressive expansion** - Add services only when you need them

---

## Troubleshooting

**Service won't start:**
```bash
op run --env-file=.env -- docker compose logs -f service-name
```

**Can't access Komodo:**
```bash
docker compose ps
# Check if port 9120 is accessible
curl http://10.10.10.112:9120
```

**1Password secret not found:**
```bash
op item list --vault=Server
op item get postgres --vault=Server
```

---

**Remember:** You can see everything in Komodo! Use it to monitor as you build. 🚀
