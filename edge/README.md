# Edge Services - Reverse Proxy, DNS & SSO

Internet-facing services that route and secure traffic to your homelab.

## Overview

**VM Name:** edge
**IP Address:** 10.10.10.110
**Resources:** 4GB RAM, 2 CPU cores, 30GB storage
**Network:** VLAN 10 (Trusted)

## Available Services

| Service | Port | Status |
|---------|------|--------|
| **Traefik** | 80, 443, 8080 | ← **Start here!** |
| AdGuard Home | 53, 3000 | In `docker-compose.full.yml` |
| Authentik | 9000 | In `docker-compose.full.yml` |

## Progressive Setup

**Start with Traefik, add others as needed.**

See **[PROGRESSIVE-SETUP.md](./PROGRESSIVE-SETUP.md)** for detailed guide.

## Quick Start (Traefik Only)

### 1. Create Cloudflare 1Password Secret

```bash
op item create --category=login --title=cloudflare \
  --vault=Server \
  email=your-email@example.com \
  'api_token=your-cloudflare-api-token'
```

**Get Cloudflare API token:**
- Cloudflare → My Profile → API Tokens → Create Token
- Template: "Edit zone DNS"
- Copy token

### 2. Update Traefik Config

Edit `config/traefik/traefik.yml` - update your email for Let's Encrypt.

### 3. Create acme.json

```bash
touch data/traefik/acme.json
chmod 600 data/traefik/acme.json
```

### 4. Deploy

```bash
op run --env-file=.env -- docker compose up -d
op run --env-file=.env -- docker compose logs -f
```

The `.env` file already contains 1Password references for Cloudflare credentials.

### 5. Access Dashboard

http://10.10.10.110:8080

That's it! Traefik is running and ready to route traffic.

## What Traefik Does

- **Automatic HTTPS** - Let's Encrypt certificates via Cloudflare DNS
- **Reverse Proxy** - Routes traffic to your services
- **Service Discovery** - Automatically detects Docker containers
- **Middlewares** - Authentication, rate limiting, headers

## Adding Services

When you deploy other services (Grafana, Jellyfin, etc.), add Traefik labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.homelab.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
```

Traefik automatically:
- Creates route for the domain
- Requests SSL certificate
- Routes HTTPS traffic to your service

## File Structure

```
edge/
├── docker-compose.yml          # Traefik only (start here!)
├── docker-compose.full.yml     # All edge services
├── PROGRESSIVE-SETUP.md        # Step-by-step guide
├── dc                          # Docker-compose wrapper
│
├── config/
│   └── traefik/
│       ├── traefik.yml         # Main config
│       └── dynamic/            # Dynamic config (middlewares)
│
└── data/
    ├── traefik/
    │   ├── acme.json          # SSL certificates (generated)
    │   └── logs/
    └── adguard/               # (when you add AdGuard)
```

## Monitoring

**Komodo:** http://10.10.10.112:9120
**Traefik Dashboard:** http://10.10.10.110:8080

## Troubleshooting

**Traefik won't start:**
```bash
op run --env-file=.env -- docker compose logs traefik
ls -la data/traefik/acme.json  # Should be 600
cat .env  # Check 1Password references
op read "op://Server/cloudflare/api_token"  # Test 1Password connection
```

**SSL not working:**
```bash
op run --env-file=.env -- docker compose logs traefik | grep acme
# Check Cloudflare API token permissions
```

## Next Steps

1. ✅ **Traefik running** - You're done with Phase 1!
2. 🚧 **Deploy other services** - They'll use Traefik for routing
3. 🚧 **Add AdGuard** - When you want network-wide ad blocking (Phase 2)
4. 🚧 **Add Authentik** - When you need SSO (Phase 3)

---

**Start with:** Traefik only (already configured!)
**Next:** See [PROGRESSIVE-SETUP.md](./PROGRESSIVE-SETUP.md) for adding AdGuard & Authentik
