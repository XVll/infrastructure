# Edge Host

Reverse proxy, DNS, and authentication services.

## Services

| Service | Port | Deploy Order | Purpose |
|---------|------|--------------|---------|
| Traefik | 80/443 | 1st | Reverse proxy + SSL |
| AdGuard Home | 53/3001 | 2nd | DNS filtering |
| Authentik | 9000/9443 | 3rd | SSO/authentication |

## Quick Start

```bash
# Deploy Traefik first
cd /opt/homelab
op run --env-file=.env -- docker compose up -d traefik

# Access Traefik dashboard
open http://10.10.10.110:8080

# Deploy AdGuard and Authentik
op run --env-file=.env -- docker compose up -d adguard
op run --env-file=.env -- docker compose up -d authentik
```

## Configuration

### Traefik
- Automatic SSL with Let's Encrypt
- Configured for Cloudflare DNS challenge
- Dashboard: http://10.10.10.110:8080

### AdGuard Home
- Set as primary DNS in UniFi controller
- Admin interface: http://10.10.10.110:3001
- Configure local DNS entries for homelab services

### Authentik
- Requires PostgreSQL + Redis on db host
- Web UI: http://10.10.10.110:9000
- Configure SSO for services via Traefik forward auth

## Notes

- Deploy Traefik before other web services
- AdGuard setup wizard runs on first access
- Authentik connects to db host (10.10.10.111)
