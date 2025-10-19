# Progressive Setup Guide - Edge Services

Start with Traefik, then add services one by one.

## Phase 1: Traefik Only (Start Here!)

Traefik is your reverse proxy - it routes traffic to all your services and handles SSL/TLS.

### 1. Prerequisites

**Domain Setup:**
- You need a domain (e.g., `homelab.example.com`)
- Using Cloudflare for DNS (free)
- Cloudflare API token for Let's Encrypt DNS challenge

### 2. Create 1Password Secrets

```bash
# Cloudflare credentials for Let's Encrypt
op item create --category=login --title=cloudflare \
  --vault=Server \
  email=your-email@example.com \
  'api_token=your-cloudflare-api-token'
```

**How to get Cloudflare API token:**
1. Log into Cloudflare
2. Go to My Profile → API Tokens
3. Create Token → Edit Zone DNS template
4. Zone Resources: Include → Specific zone → your domain
5. Copy the token

### 3. Configure Traefik

The config file at `config/traefik/traefik.yml` is already set up, but review:

```yaml
# Key settings in traefik.yml:
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com  # Update this!
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare
```

### 4. Create acme.json

```bash
cd data/traefik
touch acme.json
chmod 600 acme.json
cd ../..
```

### 5. Deploy Traefik

```bash
./dc up -d
./dc logs -f
```

### 6. Test Traefik

**Access Dashboard:**
- http://10.10.10.110:8080

You should see:
- Traefik dashboard
- No routers yet (that's fine!)
- HTTP/HTTPS entry points

**Check in Komodo:**
- Go to http://10.10.10.112:9120
- You should see Traefik container running

### 7. Test SSL Certificate

Once you add a service with a domain label, Traefik will automatically:
- Request Let's Encrypt certificate via Cloudflare DNS
- Store it in `data/traefik/acme.json`
- Auto-renew before expiration

**Once Traefik is working, move to Phase 2.**

---

## Phase 2: Add AdGuard Home

AdGuard provides network-wide DNS filtering and ad blocking.

### 1. Update docker-compose.yml

Copy the `adguard` section from `docker-compose.full.yml` to `docker-compose.yml`.

### 2. Deploy

```bash
./dc up -d
./dc logs -f adguard
```

### 3. Initial Setup

**Access:** http://10.10.10.110:3000

- Set admin username/password
- Configure upstream DNS (1.1.1.1, 8.8.8.8)
- Set listening interface to all

### 4. Configure Your Router

**Point your router's DNS to:** 10.10.10.110

Now all devices on your network use AdGuard for DNS.

### 5. Test

- Browse the web - ads should be blocked
- Access dashboard: https://dns.homelab.example.com (via Traefik)

---

## Phase 3: Add Authentik (SSO)

Authentik provides single sign-on for all your services.

### Prerequisites

- PostgreSQL must be running on data VM (10.10.10.111)
- Redis must be running on data VM

### 1. Create Database for Authentik

```bash
# SSH to data VM
ssh data-vm
docker exec -it postgres psql -U postgres

# In psql:
CREATE DATABASE authentik;
CREATE USER authentik WITH ENCRYPTED PASSWORD 'strong-password';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
\q
```

### 2. Create 1Password Secrets

```bash
op item create --category=database --title=authentik \
  --vault=Server \
  username=authentik \
  'db_password=your-postgres-password' \
  'secret_key='$(openssl rand -base64 50)
```

### 3. Update docker-compose.yml

Copy the `authentik-server` and `authentik-worker` sections from `docker-compose.full.yml`.

Update the connection strings to use 1Password references:
```yaml
AUTHENTIK_POSTGRESQL__HOST: 10.10.10.111
AUTHENTIK_POSTGRESQL__PASSWORD: "op://Server/authentik/db_password"
AUTHENTIK_REDIS__HOST: 10.10.10.111
AUTHENTIK_REDIS__PASSWORD: "op://Server/redis/password"
AUTHENTIK_SECRET_KEY: "op://Server/authentik/secret_key"
```

### 4. Deploy

```bash
./dc up -d
./dc logs -f authentik-server
```

### 5. Initial Setup

**Access:** https://auth.homelab.example.com

- Default: `akadmin` / `akadmin` (change immediately!)
- Configure flows, providers, applications
- Integrate with services (Grafana, etc.)

### 6. Protect Traefik Dashboard

Add authentication middleware to Traefik dashboard label.

---

## Summary

**Deployment order:**
1. ✅ Traefik - Reverse proxy (start here!)
2. ⏭️ AdGuard - DNS filtering (optional but recommended)
3. ⏭️ Authentik - SSO (when you need centralized auth)

**Traefik handles:**
- Automatic HTTPS/TLS
- Routing traffic to services
- Load balancing
- Middlewares (auth, rate limiting)

**AdGuard handles:**
- Network-wide ad blocking
- DNS filtering
- Custom DNS records

**Authentik handles:**
- Single sign-on
- User management
- LDAP/OAuth2/OIDC provider

---

## Quick Commands

```bash
# Start Traefik only
./dc up -d

# Add AdGuard
# (Edit docker-compose.yml, add adguard section)
./dc up -d

# View logs
./dc logs -f traefik
./dc logs -f adguard

# Check status
./dc ps
```

---

## Troubleshooting

**Traefik won't start:**
```bash
# Check logs
./dc logs traefik

# Check acme.json permissions
ls -la data/traefik/acme.json
# Should be -rw------- (600)

# Check Cloudflare credentials
op read "op://Server/cloudflare/api_token"
```

**SSL certificates not issued:**
- Check Cloudflare API token has DNS edit permissions
- Check domain DNS is using Cloudflare nameservers
- Check logs: `./dc logs traefik | grep acme`

**Can't access dashboard:**
- Check http://10.10.10.110:8080 (direct IP)
- Check firewall rules
- Check Traefik is running: `./dc ps`

---

**Start with:** Traefik only (already configured!)
**Monitor:** Check Komodo at http://10.10.10.112:9120
