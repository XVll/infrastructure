# Homelab Infrastructure Deployment Guide

This guide walks you through deploying the entire homelab infrastructure from scratch.

## Prerequisites

### Hardware
- Proxmox host with AMD Ryzen 9 9900X, 64GB RAM
- UniFi network equipment (UDM/USG + switches)
- NAS storage (Xpenology or similar)

### Software Requirements
- Proxmox VE installed and configured
- UniFi Controller accessible
- Git installed on your workstation
- SSH access to VMs
- Docker and Docker Compose on each VM

### Network Requirements
- VLANs configured: 10, 11, 12, 13, 30
- DNS: AdGuard will be configured, but need temporary DNS initially
- Domain name with Cloudflare DNS management (for automatic HTTPS)

---

## Phase 1: Network Configuration

### 1.1 Configure VLANs in UniFi

Create the following VLANs:

```
VLAN 10 - Frontend      - 10.10.10.0/24
VLAN 11 - Data Tier     - 10.10.11.0/24 (isolated, no internet)
VLAN 12 - Media Apps    - 10.10.12.0/24
VLAN 13 - Web Apps      - 10.10.13.0/24
VLAN 30 - IoT           - 10.10.30.0/24
```

### 1.2 Configure Firewall Rules

**VLAN 11 (Data Tier) - Complete Isolation:**
```
# Allow specific VMs to access databases
ALLOW: 10.10.10.10 → 10.10.11.10:5432 (Authentik → PostgreSQL)
ALLOW: 10.10.10.10 → 10.10.11.10:6379 (Authentik → Redis)
ALLOW: 10.10.12.10 → 10.10.11.10:5432 (n8n/Paperless → PostgreSQL)
ALLOW: 10.10.12.10 → 10.10.11.10:6379 (n8n → Redis)
ALLOW: 10.10.10.20 → 10.10.11.10:* (Monitoring → Databases)

# Deny all outbound from Data Tier
DENY: 10.10.11.10 → * (databases never initiate outbound)

# Deny internet access
DENY: 10.10.11.0/24 → WAN
```

**Edge Services (VLAN 10):**
```
# Allow inbound HTTP/HTTPS from internet
ALLOW: * → 10.10.10.10:80,443

# Allow DNS from all homelab
ALLOW: 10.10.0.0/16 → 10.10.10.10:53
```

---

## Phase 2: Provision VMs in Proxmox

### 2.1 Create VMs

Create the following VMs manually or use Terraform:

| VM | Hostname | VLAN | IP | RAM | CPU | Disk |
|----|----------|------|-----|-----|-----|------|
| VM 1 | edge-services | 10 | 10.10.10.10 | 4GB | 2 | 30GB |
| VM 2 | data-tier | 11 | 10.10.11.10 | 10GB | 4 | 100GB |
| VM 3 | observability | 10 | 10.10.10.20 | 6GB | 4 | 80GB |
| VM 4 | media-automation | 12 | 10.10.12.10 | 16GB | 8 | 200GB |
| VM 5 | coolify | 13 | 10.10.13.10 | 8GB | 4 | 100GB |

### 2.2 Install Ubuntu Server 22.04 LTS

For each VM:
1. Download Ubuntu Server 22.04 LTS ISO
2. Create VM in Proxmox
3. Assign to appropriate VLAN
4. Set static IP address
5. Install SSH server
6. Update system: `sudo apt update && sudo apt upgrade -y`

### 2.3 Install Docker and Docker Compose

On each VM:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Verify installation
docker --version
docker compose version
```

---

## Phase 3: Deploy VM 2 (Data Tier) - Foundation

VM 2 must be deployed first as all other services depend on it.

### 3.1 Clone Repository

```bash
cd /opt
sudo git clone https://github.com/your-username/infrastructure.git homelab
sudo chown -R $USER:$USER /opt/homelab
cd /opt/homelab/vm2-data-tier
```

### 3.2 Generate TLS Certificates

```bash
# PostgreSQL certificates
cd certs/postgres
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=postgres.homelab.local"
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"
chmod 600 server.key ca.key
chmod 644 server.crt ca.crt

# MongoDB certificates
cd ../mongodb
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=mongodb.homelab.local"
cat server.key server.crt > server.pem
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"
chmod 600 server.pem server.key ca.key

# Repeat for Redis and MinIO (see vm2-data-tier/README.md)
```

### 3.3 Configure Environment

```bash
cp .env.example .env
nano .env

# Generate strong passwords:
openssl rand -base64 32
```

Fill in all passwords in `.env`.

### 3.4 Deploy

```bash
docker compose up -d
docker compose logs -f
```

### 3.5 Initialize Databases

```bash
# Create application databases
docker exec -it postgres psql -U postgres <<EOF
CREATE DATABASE authentik;
CREATE USER authentik WITH ENCRYPTED PASSWORD 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

CREATE DATABASE paperless;
CREATE USER paperless WITH ENCRYPTED PASSWORD 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless;

CREATE DATABASE grafana;
CREATE USER grafana WITH ENCRYPTED PASSWORD 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
EOF

# Verify
docker exec -it postgres psql -U postgres -c "\l"
```

### 3.6 Verify Health

```bash
# Check all services are running
docker compose ps

# Test PostgreSQL
docker exec -it postgres psql -U postgres -c "SELECT version();"

# Test MongoDB
docker exec -it mongodb mongosh -u root -p

# Test Redis
docker exec -it redis redis-cli --tls --cert /certs/server.crt --key /certs/server.key --cacert /certs/ca.crt PING

# Test MinIO
docker exec -it minio mc alias set local http://localhost:9000 minioadmin YOUR_PASSWORD
docker exec -it minio mc admin info local
```

---

## Phase 4: Deploy VM 1 (Edge Services)

### 4.1 Setup

```bash
cd /opt/homelab/vm1-edge-services
cp .env.example .env
nano .env
```

Configure:
- Domain name
- Cloudflare API credentials
- Database passwords (must match VM 2)
- Authentik secret key: `openssl rand -base64 60`

### 4.2 Configure Traefik

Edit `config/traefik/traefik.yml`:
- Set your email address for Let's Encrypt
- Verify Cloudflare DNS challenge settings

### 4.3 Deploy

```bash
# Create ACME file with correct permissions
touch data/traefik/acme.json
chmod 600 data/traefik/acme.json

# Start services
docker compose up -d
docker compose logs -f
```

### 4.4 Configure AdGuard Home

1. Access: `http://10.10.10.10:3000`
2. Complete setup wizard
3. Set admin credentials
4. Configure upstream DNS: `1.1.1.1`, `8.8.8.8`
5. Add DNS rewrites: `*.homelab.local → 10.10.10.10`
6. **Update your router's DHCP:** Set DNS server to `10.10.10.10`

### 4.5 Configure Authentik

1. Access: `https://auth.homelab.local`
2. Create admin account
3. Create Traefik provider (Forward Auth)
4. Create applications for each service
5. Create user groups (Admin, Users, Media)
6. Configure policies and access control

### 4.6 Verify

```bash
# Check Traefik dashboard
curl -I https://traefik.homelab.local

# Check certificates are issued
cat data/traefik/acme.json | jq '.cloudflare.Certificates[] | .domain'

# Test DNS resolution
dig @10.10.10.10 auth.homelab.local
```

---

## Phase 5: Deploy VM 3 (Observability)

### 5.1 Setup

```bash
cd /opt/homelab/vm3-observability
cp .env.example .env
nano .env
```

Configure:
- Grafana admin password
- Grafana secret key: `openssl rand -base64 32`
- Database password (must match VM 2)
- Authentik OAuth credentials

### 5.2 Configure Authentik OAuth for Grafana

In Authentik:
1. Create new OAuth2/OIDC Provider
2. Client type: Confidential
3. Redirect URIs: `https://grafana.homelab.local/login/generic_oauth`
4. Copy Client ID and Client Secret to VM3 `.env`

### 5.3 Deploy

```bash
docker compose up -d
docker compose logs -f
```

### 5.4 Configure Grafana

1. Access: `https://grafana.homelab.local`
2. Login with Authentik SSO
3. Verify datasources are working (Prometheus, Loki)
4. Import dashboards from Grafana.com:
   - Node Exporter Full: 1860
   - Docker Monitoring: 893
   - PostgreSQL: 9628
   - Traefik: 11462

### 5.5 Configure Uptime Kuma

1. Access: `http://10.10.10.20:3001` (or via Traefik)
2. Create admin account
3. Add monitors for all critical services:
   - PostgreSQL: 10.10.11.10:5432
   - Redis: 10.10.11.10:6379
   - Traefik: https://traefik.homelab.local
   - Authentik: https://auth.homelab.local
   - All application URLs

---

## Phase 6: Deploy VM 4 (Media & Automation)

### 6.1 Mount NAS Storage

First, mount your NAS on VM 4:

```bash
# Install NFS client
sudo apt install nfs-common -y

# Create mount points
sudo mkdir -p /mnt/nas/{media,downloads}

# Add to /etc/fstab
echo "10.10.10.30:/volume1/media /mnt/nas/media nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "10.10.10.30:/volume1/downloads /mnt/nas/downloads nfs defaults 0 0" | sudo tee -a /etc/fstab

# Mount
sudo mount -a
df -h
```

### 6.2 Setup

```bash
cd /opt/homelab/vm4-media-automation
cp .env.example .env
nano .env
```

Configure:
- NAS paths: `/mnt/nas/media`, `/mnt/nas/downloads`
- Database passwords (must match VM 2)
- n8n encryption key: `openssl rand -base64 32`

### 6.3 Deploy

```bash
docker compose up -d
docker compose logs -f
```

### 6.4 Configure Services

**Prowlarr (Indexers):**
1. Access: `https://prowlarr.homelab.local`
2. Add indexers (e.g., NZBGeek, DrunkenSlug, public trackers)
3. Configure FlareSolverr: `http://flaresolverr:8191`
4. Add applications: Sonarr, Radarr

**Sonarr (TV Shows):**
1. Access: `https://sonarr.homelab.local`
2. Settings → Media Management → Root Folder: `/tv`
3. Settings → Download Clients → Add qBittorrent
4. Settings → Indexers → Sync from Prowlarr

**Radarr (Movies):**
1. Similar to Sonarr, root folder: `/movies`

**Jellyfin (Media Server):**
1. Access: `https://jellyfin.homelab.local`
2. Complete initial setup
3. Add libraries: Movies (`/media/movies`), TV (`/media/tv`)
4. Enable hardware transcoding (Settings → Playback)

**n8n (Automation):**
1. Access: `https://n8n.homelab.local`
2. Create owner account
3. Create workflows (e.g., backup automation, notifications)

**Paperless-ngx (Documents):**
1. Access: `https://paperless.homelab.local`
2. Login with admin credentials from `.env`
3. Configure consume folder: `/consume`
4. Set up document processing rules

### 6.5 Get API Keys for Monitoring

After initial setup, retrieve API keys:

```bash
# Sonarr: Settings → General → Security → API Key
# Radarr: Settings → General → Security → API Key
# Prowlarr: Settings → General → Security → API Key
```

Add these to `.env` and restart:

```bash
nano .env
# Add API keys
docker compose up -d exportarr-sonarr exportarr-radarr exportarr-prowlarr
```

---

## Phase 7: Deploy VM 5 (Coolify)

### 7.1 Install Coolify

SSH to VM 5 and run:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

### 7.2 Configure

1. Access: `https://coolify.homelab.local` (configure in Traefik)
2. Complete initial setup
3. Configure PostgreSQL connection to VM 2 (optional)
4. Add GitHub integration for CI/CD
5. Deploy your web applications

---

## Phase 8: Deploy VM 6 (NAS) and VM 7 (Home Assistant)

### VM 6: Xpenology NAS
- Install Xpenology DSM
- Configure network: VLAN 10, IP 10.10.10.30
- Create shared folders: `media`, `downloads`, `backups`
- Enable NFS/SMB for VM 4 access
- Install Node Exporter for monitoring

### VM 7: Home Assistant OS
- Install Home Assistant OS
- Configure network: VLAN 30, IP 10.10.30.10
- Complete onboarding
- Enable Prometheus integration
- Add devices and automations

---

## Phase 9: Monitoring and Exporters

### 9.1 Install Node Exporter on All VMs

On each VM (1-5):

```bash
docker run -d \
  --name=node-exporter \
  --restart=unless-stopped \
  -p 9100:9100 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  --pid=host \
  prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/rootfs \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($$|/)'
```

### 9.2 Install Database Exporters on VM 2

```bash
cd /opt/homelab/vm2-data-tier

# Add exporters to docker-compose.yml (or create separate compose file)
docker compose -f docker-compose-exporters.yml up -d
```

Create `docker-compose-exporters.yml`:
```yaml
version: '3.8'
services:
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://monitoring:PASSWORD@postgres:5432/postgres?sslmode=require"
    ports:
      - "9187:9187"
    networks:
      - data_tier

  mongodb-exporter:
    image: percona/mongodb_exporter:latest
    command: --mongodb.uri=mongodb://monitoring:PASSWORD@mongodb:27017
    ports:
      - "9216:9216"
    networks:
      - data_tier

  redis-exporter:
    image: oliver006/redis_exporter
    environment:
      REDIS_ADDR: "rediss://redis:6379"
      REDIS_PASSWORD: "PASSWORD"
    ports:
      - "9121:9121"
    networks:
      - data_tier

networks:
  data_tier:
    external: true
```

---

## Phase 10: Backup Configuration

### 10.1 Create Backup Scripts

See each VM's README for specific backup procedures.

### 10.2 Configure Automated Backups

Create `/usr/local/bin/backup-all.sh`:

```bash
#!/bin/bash
set -euo pipefail

BACKUP_ROOT="/mnt/nas/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# VM 2: Databases
ssh 10.10.11.10 "/opt/homelab/vm2-data-tier/scripts/backup.sh"

# VM 1: Configs
ssh 10.10.10.10 "cd /opt/homelab/vm1-edge-services && tar czf /tmp/edge-backup-$DATE.tar.gz data/"
scp 10.10.10.10:/tmp/edge-backup-$DATE.tar.gz "$BACKUP_ROOT/vm1/"

# Repeat for other VMs...

# Offsite backup to Backblaze B2
restic -r b2:homelab-backups:/ backup "$BACKUP_ROOT"

# Cleanup old backups (keep 30 days)
find "$BACKUP_ROOT" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

Schedule with cron:
```bash
sudo crontab -e
# Daily at 2 AM
0 2 * * * /usr/local/bin/backup-all.sh >> /var/log/backup-all.log 2>&1
```

---

## Phase 11: Security Hardening

### 11.1 Enable UFW Firewall on Each VM

```bash
# VM 1 (Edge Services)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 53
sudo ufw enable

# VM 2 (Data Tier) - NO INTERNET ACCESS
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw allow from 10.10.10.10 to any port 5432
sudo ufw allow from 10.10.10.10 to any port 6379
sudo ufw allow from 10.10.12.10 to any port 5432
sudo ufw allow from 10.10.12.10 to any port 6379
sudo ufw allow from 10.10.10.20 to any
sudo ufw enable

# Repeat for other VMs...
```

### 11.2 Configure Fail2Ban

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 11.3 Regular Updates

```bash
# Enable unattended upgrades
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## Phase 12: Verification and Testing

### 12.1 Test All Services

Create a checklist:
- [ ] All VMs accessible via SSH
- [ ] DNS resolving via AdGuard
- [ ] HTTPS certificates issued for all services
- [ ] Authentik SSO working for all applications
- [ ] Databases accepting connections
- [ ] Grafana showing metrics from all exporters
- [ ] Loki receiving logs
- [ ] Uptime Kuma monitoring all services
- [ ] Media apps can reach qBittorrent
- [ ] Sonarr/Radarr can communicate with Prowlarr
- [ ] Jellyfin can access NAS media
- [ ] n8n can execute workflows
- [ ] Backups running successfully

### 12.2 Load Testing

Test under load:
```bash
# Test Traefik throughput
ab -n 1000 -c 10 https://grafana.homelab.local/

# Test database connections
pgbench -h 10.10.11.10 -U postgres -d postgres -c 10 -t 100
```

### 12.3 Failover Testing

Test service recovery:
```bash
# Stop a critical service
docker stop postgres

# Verify alerts trigger in Grafana
# Verify Uptime Kuma detects failure
# Restart and verify recovery
docker start postgres
```

---

## Troubleshooting

### Services won't start
```bash
# Check logs
docker compose logs service-name

# Check disk space
df -h

# Check memory
free -h

# Check network connectivity
ping 10.10.11.10
```

### Database connection errors
```bash
# Verify firewall rules
sudo ufw status

# Test connection
telnet 10.10.11.10 5432

# Check PostgreSQL logs
docker exec postgres tail -f /var/log/postgresql/postgresql-*.log
```

### DNS not resolving
```bash
# Test AdGuard
dig @10.10.10.10 google.com

# Check AdGuard logs
docker compose logs adguard

# Verify router DNS settings
```

### HTTPS certificate issues
```bash
# Check Traefik logs
docker compose logs traefik | grep acme

# Verify Cloudflare API token
docker exec traefik env | grep CF_

# Force certificate renewal
docker exec traefik rm /acme.json
docker compose restart traefik
```

---

## Maintenance Schedule

**Daily:**
- Check Uptime Kuma for service failures
- Review Grafana dashboards for anomalies

**Weekly:**
- Review backup logs
- Check disk space usage
- Review authentication logs in Authentik

**Monthly:**
- Update all Docker images: `docker compose pull && docker compose up -d`
- Review and rotate old logs
- Test backup restoration
- Update VM OS packages: `sudo apt update && sudo apt upgrade -y`

**Quarterly:**
- Review and update firewall rules
- Security audit via Authentik logs
- Capacity planning review
- Update documentation

---

## Next Steps

After deployment:
1. Set up offsite backups (Backblaze B2, AWS S3)
2. Configure alerting (email, Slack, Discord)
3. Implement log retention policies
4. Create runbooks for common issues
5. Document your specific configurations
6. Set up CI/CD pipelines in Coolify

---

## Support

For issues specific to this infrastructure:
- Check each VM's README.md
- Review service-specific documentation
- Check GitHub Issues

For general homelab questions:
- r/homelab
- r/selfhosted
- Homelab Discord communities
