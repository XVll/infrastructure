# Homelab Infrastructure

Progressive Docker-based infrastructure on Proxmox VMs using VirtioFS for stateless deployments.

## Documentation

- **[INFRASTRUCTURE.md](INFRASTRUCTURE.md)** - All documentation, progress, setup guides, and notes

## Quick Reference

**Network:** VLAN 10 (10.10.10.0/24)

| VM | IP | Services |
|----|-----|----------|
| db | 10.10.10.111 | MongoDB, PostgreSQL, Redis, MinIO |
| observability | 10.10.10.112 | Portainer, Prometheus, Grafana, Loki |
| edge | 10.10.10.110 | Traefik, AdGuard, Authentik |
| media | 10.10.10.113 | Jellyfin, Arr Stack, n8n, Paperless |
| coolify | 10.10.10.114 | Coolify PaaS |

**Architecture:**
- Proxmox host: `/flash/docker/homelab/` (git repo)
- Each VM: `/opt/homelab/` (VirtioFS mount)
- All VMs are stateless and disposable

**Common Pattern:**
```bash
cd /opt/homelab
op run --env-file=.env -- docker compose up -d <service>
docker compose logs -f <service>
```

See [INFRASTRUCTURE.md](INFRASTRUCTURE.md) for detailed progress and notes.
