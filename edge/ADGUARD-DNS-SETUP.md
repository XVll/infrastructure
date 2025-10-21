# AdGuard DNS Setup for Internal Domain Resolution

## Overview

This homelab uses **public domain names** (`*.onurx.com`) with valid Cloudflare certificates, but services are accessed **internally** via AdGuard DNS rewrites pointing to internal IPs.

## Why This Approach?

- Valid SSL certificates (no browser warnings)
- Internal-only access (services not exposed to internet)
- Simple domain names (no `.homelab.local`)
- Works seamlessly with Cloudflare DNS-01 challenge

## Required DNS Rewrites in AdGuard

After deploying AdGuard (10.10.10.110), add these DNS rewrites:

**Filters → DNS rewrites → Add DNS rewrite**

| Domain | Answer | Notes |
|--------|--------|-------|
| `auth.onurx.com` | `10.10.10.110` | Authentik SSO |
| `portainer.onurx.com` | `10.10.10.110` | Portainer (via Traefik) |
| `grafana.onurx.com` | `10.10.10.110` | Grafana (via Traefik) |
| `minio.onurx.com` | `10.10.10.110` | MinIO Console (via Traefik) |
| `s3.onurx.com` | `10.10.10.110` | MinIO S3 API (via Traefik) |
| `sonarr.onurx.com` | `10.10.10.110` | Sonarr (via Traefik) |
| `radarr.onurx.com` | `10.10.10.110` | Radarr (via Traefik) |
| `prowlarr.onurx.com` | `10.10.10.110` | Prowlarr (via Traefik) |
| `jellyfin.onurx.com` | `10.10.10.110` | Jellyfin (via Traefik) |
| `qbittorrent.onurx.com` | `10.10.10.110` | qBittorrent (via Traefik) |
| `n8n.onurx.com` | `10.10.10.110` | n8n (via Traefik) |
| `paperless.onurx.com` | `10.10.10.110` | Paperless (via Traefik) |
| `coolify.onurx.com` | `10.10.10.110` | Coolify (via Traefik) |

**All domains point to 10.10.10.110** (Traefik reverse proxy on edge VM)

## How It Works

1. **Client Request**: Browser requests `https://grafana.onurx.com`
2. **AdGuard DNS**: Resolves to `10.10.10.110` (Traefik)
3. **Traefik**: Routes to Grafana at `10.10.10.112:3000`
4. **SSL Certificate**: Valid wildcard cert `*.onurx.com` from Cloudflare/Let's Encrypt
5. **Response**: Grafana served over HTTPS with valid certificate

## Cloudflare Setup (Already Configured)

Traefik uses Cloudflare API to obtain wildcard certificate:
- Certificate: `*.onurx.com`
- Challenge: DNS-01 via Cloudflare API
- Token: Stored in 1Password (`op://Server/cloudflare/api_token`)

## AdGuard Configuration Steps

1. Deploy AdGuard: `op run --env-file=.env -- docker compose up -d adguard`
2. Access setup: `http://10.10.10.110:3000`
3. Complete initial setup
4. Navigate to **Filters → DNS rewrites**
5. Add each rewrite from the table above
6. Update router DNS to `10.10.10.110`
7. Test: `nslookup grafana.onurx.com` should return `10.10.10.110`

## Testing DNS Resolution

```bash
# From any device using AdGuard as DNS
nslookup auth.onurx.com
# Should return: 10.10.10.110

# Test certificate
curl -I https://grafana.onurx.com
# Should show valid SSL certificate for *.onurx.com
```

## Security Notes

- Services are **NOT** accessible from internet (no port forwarding)
- Valid certificates prevent MITM warnings
- AdGuard provides DNS-level ad blocking + internal routing
- Authentik middleware protects services behind SSO
