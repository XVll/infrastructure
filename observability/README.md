# Observability - Monitoring & Container Management

Central monitoring, logging, and container management for all VMs.

## Overview

**VM Name:** observability
**IP Address:** 10.10.10.112
**Resources:** 6GB RAM, 4 CPU cores, 80GB storage
**Network:** VLAN 10 (Trusted)

## Available Services

| Service | Port | Status |
|---------|------|--------|
| **Komodo** | 9120 | ← **Start here!** |
| Grafana | 3000 | In `docker-compose.full.yml` |
| Prometheus | 9090 | In `docker-compose.full.yml` |
| Loki | 3100 | In `docker-compose.full.yml` |
| Alloy | 12345 | In `docker-compose.full.yml` |
| Uptime Kuma | 3001 | In `docker-compose.full.yml` |

## Quick Start: Install Komodo

**Install Komodo FIRST so you can manage containers as you build!**

### 1. Deploy Komodo

```bash
cd /opt/homelab/observability
docker compose up -d
docker compose logs -f
```

### 2. Access Komodo

Open: **http://10.10.10.112:9120**

- First time: Create admin account
- You'll see the observability VM already added

### 3. Add Other VMs to Komodo

In Komodo UI, add your other VMs:

**Add Server:**
- Name: `data`
- Address: `10.10.10.111`
- Connect via: Docker Socket over SSH

Repeat for `edge`, `media`, `coolify` VMs.

### 4. Start Building!

Now you can:
- ✅ Monitor all Docker containers from one dashboard
- ✅ View logs from any VM
- ✅ Start/stop/restart containers
- ✅ See resource usage across all VMs
- ✅ Execute commands on remote servers

**Go deploy your data VM PostgreSQL - watch it in Komodo!**

---

## Progressive Setup

Start with Komodo, add monitoring services as needed:

### Phase 1: Komodo (Start Here!)
- Already done! ✅
- Manage all Docker containers from web UI

### Phase 2: Add Grafana (When you want dashboards)
- Copy Grafana section from `docker-compose.full.yml`
- Add to `docker-compose.yml`
- Deploy: `docker compose up -d`

### Phase 3: Add Prometheus (When you want metrics)
- Copy Prometheus + Node Exporter sections
- Add to `docker-compose.yml`
- Configure scrape targets
- Deploy: `docker compose up -d`

### Phase 4: Add Loki (When you want centralized logs)
- Copy Loki + Alloy sections
- Add to `docker-compose.yml`
- Configure log collection
- Deploy: `docker compose up -d`

See `docker-compose.full.yml` for all services.

---

## Komodo Features

### Monitor Containers
- See all containers across all VMs
- Real-time status and health
- Resource usage (CPU, RAM, disk)

### Manage Deployments
- Deploy docker-compose stacks
- Update containers
- View and tail logs

### Execute Commands
- Run commands on any server
- SSH-like terminal access
- No need to SSH into VMs

### Server Monitoring
- CPU, RAM, disk usage per VM
- Network traffic
- System information

### Alerts (Optional)
- Set up notifications
- Container down alerts
- Resource threshold alerts

---

## File Structure

```
observability/
├── docker-compose.yml          # Komodo only (start here!)
├── docker-compose.full.yml     # All monitoring services
├── README.md                   # This file
└── dc                          # Docker-compose wrapper
```

---

## Next Steps

1. ✅ **Komodo installed** - You're done with Phase 1!
2. 🚧 **Deploy data tier** - Install PostgreSQL, watch in Komodo
3. 🚧 **Add Grafana later** - When you want pretty dashboards
4. 🚧 **Add Prometheus later** - When you want metrics
5. 🚧 **Add Loki later** - When you want centralized logs

---

**Access Komodo:** http://10.10.10.112:9120
**Manage:** All your Docker containers from one place!
