# Observability Host

Monitoring, management, and observability stack.

## Services

| Service | Port | Deploy Order | Purpose |
|---------|------|--------------|---------|
| Komodo | 9120 | 1st | Container management UI |
| Prometheus | 9090 | 2nd | Metrics storage |
| Grafana | 3000 | 3rd | Dashboards |
| Loki | 3100 | 4th | Log aggregation |
| Alloy | 12345 | 5th | Metrics/logs collector |

## Quick Start

```bash
# Deploy Komodo first (requires MongoDB on db host)
cd /opt/homelab
op run --env-file=.env -- docker compose up -d komodo

# Access Komodo UI
open http://10.10.10.112:9120

# Deploy monitoring stack progressively
op run --env-file=.env -- docker compose up -d prometheus
op run --env-file=.env -- docker compose up -d grafana
op run --env-file=.env -- docker compose up -d loki
op run --env-file=.env -- docker compose up -d alloy
```

## Komodo Setup

1. Create admin account on first access
2. Add all VM hosts as servers
3. Configure Docker socket access for each host
4. Monitor container status across infrastructure

## Notes

- Komodo connects to MongoDB on db host (10.10.10.111:27017)
- Loki uses MinIO on db host for log storage
- Prometheus scrapes metrics from all hosts
