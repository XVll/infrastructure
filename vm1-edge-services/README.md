# VM 1: Edge Services

Entry point for all external traffic, providing reverse proxy, DNS, and authentication.

## Overview

**VLAN:** 10 (10.10.10.0/24)
**IP Address:** 10.10.10.10
**Resources:** 4GB RAM, 2 CPU cores, 30GB storage
**Security:** Public-facing, requires careful hardening

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Traefik | 80/443 | Reverse proxy with automatic HTTPS |
| AdGuard Home | 53, 3000 | DNS server with ad-blocking |
| Authentik | 9000 | SSO and identity provider |

## Prerequisites

### 1. Domain Setup

You need a domain name with DNS managed by Cloudflare (for automatic HTTPS):

1. Register a domain or use an existing one
2. Transfer DNS management to Cloudflare
3. Create an API token in Cloudflare:
   - Go to: Profile → API Tokens → Create Token
   - Use template: "Edit zone DNS"
   - Zone Resources: Include → Specific zone → your-domain.com
   - Copy the token for `.env`

### 2. DNS Records

Add these A records in Cloudflare (pointing to your public IP or local IP if using local DNS):

```
A    @                    your-public-ip
A    *.homelab.local      10.10.10.10 (or your-public-ip)
A    auth                 10.10.10.10
A    traefik              10.10.10.10
A    dns                  10.10.10.10
A    grafana              10.10.10.10
A    sonarr               10.10.10.10
A    radarr               10.10.10.10
A    jellyfin             10.10.10.10
... (add all your services)
```

### 3. Firewall Configuration

**Router/Firewall Rules:**
```bash
# Allow inbound HTTP/HTTPS from internet
ALLOW: * → 10.10.10.10:80 (HTTP)
ALLOW: * → 10.10.10.10:443 (HTTPS)

# Allow inbound DNS from homelab
ALLOW: 10.10.0.0/16 → 10.10.10.10:53 (DNS)

# Block direct access to dashboard from internet
DENY: WAN → 10.10.10.10:8080 (Traefik Dashboard)
DENY: WAN → 10.10.10.10:3000 (AdGuard Dashboard)
```

## Initial Setup

### 1. Configure Environment

```bash
cd vm1-edge-services
cp .env.example .env
# Edit .env with your actual values

# Generate Authentik secret key
openssl rand -base64 60

# Set proper permissions for Traefik ACME file
touch data/traefik/acme.json
chmod 600 data/traefik/acme.json
```

### 2. Update Traefik Email

Edit `config/traefik/traefik.yml` and set your email:
```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com  # CHANGE THIS
```

### 3. Deploy Services

```bash
docker compose up -d
docker compose logs -f
```

### 4. Initial Configuration

#### AdGuard Home Setup

1. Access: `http://10.10.10.10:3000`
2. Complete initial setup wizard:
   - Admin interface: Port 3000
   - DNS server: Port 53
   - Create admin username/password
3. Configure upstream DNS servers:
   - Go to Settings → DNS Settings
   - Add: `1.1.1.1`, `8.8.8.8`, `2606:4700:4700::1111`
4. Enable DNS-over-HTTPS (optional):
   - Go to Settings → Encryption
   - Upload certificate or use Let's Encrypt
5. Configure DNS rewrites for local services:
   - Go to Filters → DNS rewrites
   - Add rewrites for `*.homelab.local → 10.10.10.10`

**Update your router's DHCP settings:**
- Primary DNS: 10.10.10.10 (AdGuard)
- Secondary DNS: 1.1.1.1 (Cloudflare)

#### Authentik Setup

1. Access: `https://auth.homelab.local`
2. Complete initial setup:
   - Create admin account
   - Configure default tenant
3. Create a Traefik provider:
   - Go to Applications → Providers
   - Create new provider: Forward Auth (single application)
   - Name: Traefik
   - External host: `https://auth.homelab.local`
   - Auth URL: `/outpost.goauthentik.io/auth/traefik`
4. Create applications for each service:
   - Go to Applications → Applications
   - Create application for each service (Grafana, Sonarr, etc.)
   - Assign provider: Traefik
   - Set launch URL to service URL
5. Create user groups and policies:
   - Admin group (full access)
   - Users group (limited access)
   - Media group (only media services)

#### Traefik Verification

1. Check dashboard: `https://traefik.homelab.local`
2. Verify HTTPS certificates are issued
3. Check logs: `docker compose logs traefik`
4. Verify services are routing correctly:
   ```bash
   curl -I https://grafana.homelab.local
   curl -I https://auth.homelab.local
   ```

## Service Configuration

### Traefik

**Dashboard Access:** `https://traefik.homelab.local` (protected by Authentik)

**Key Features:**
- Automatic HTTPS with Let's Encrypt (Cloudflare DNS challenge)
- Forward authentication via Authentik
- Security headers on all routes
- Access logs for troubleshooting
- Prometheus metrics for monitoring

**Add a new service:**

1. Add service definition to `config/traefik/dynamic/authentik.yml`:
   ```yaml
   http:
     services:
       my-service:
         loadBalancer:
           servers:
             - url: "http://10.10.12.10:8080"

     routers:
       my-service:
         rule: "Host(`my-service.homelab.local`)"
         entryPoints:
           - websecure
         service: my-service
         middlewares:
           - authentik
           - security-headers
         tls:
           certResolver: cloudflare
   ```

2. Add DNS record in AdGuard or Cloudflare
3. Traefik will auto-reload and route traffic

### AdGuard Home

**Dashboard Access:** `https://dns.homelab.local` (protected by Authentik)

**Features:**
- DNS-based ad blocking
- Custom DNS rewrites for homelab services
- Query logs and statistics
- Upstream DNS configuration
- DHCP server (optional)

**Recommended Blocklists:**
- AdGuard DNS filter
- AdAway Default Blocklist
- EasyList
- Dan Pollock's List

**Custom DNS Rewrites:**
```
*.homelab.local → 10.10.10.10
grafana.homelab.local → 10.10.10.20 (direct to Grafana VM)
```

### Authentik

**Dashboard Access:** `https://auth.homelab.local`

**Features:**
- Single Sign-On (SSO) for all services
- LDAP provider (for services that don't support OIDC)
- User and group management
- Multi-factor authentication (MFA)
- OAuth2/OIDC provider

**Recommended Policies:**
- Password policy: 12+ characters, complexity requirements
- MFA policy: Required for admin accounts
- Session timeout: 24 hours for users, 1 hour for admins

## Backup Strategy

```bash
#!/bin/bash
# Backup script for Edge Services

BACKUP_DIR="/backups/vm1"
DATE=$(date +%Y%m%d_%H%M%S)

# Traefik ACME certificates
cp data/traefik/acme.json "$BACKUP_DIR/traefik/acme_$DATE.json"

# AdGuard Home configuration
tar czf "$BACKUP_DIR/adguard/adguard_$DATE.tar.gz" data/adguard/conf/

# Authentik data (media, templates)
tar czf "$BACKUP_DIR/authentik/authentik_$DATE.tar.gz" data/authentik/

# Keep 30 days
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

Schedule with cron:
```bash
# Daily at 3 AM
0 3 * * * /usr/local/bin/backup-edge-services.sh >> /var/log/backup-edge-services.log 2>&1
```

## Maintenance

### Update Containers

```bash
docker compose pull
docker compose up -d
docker compose logs -f
```

### Monitor Health

```bash
# Check all services
docker compose ps

# Check Traefik health
curl http://localhost:80/ping

# Check AdGuard DNS
dig @10.10.10.10 example.com

# Check Authentik
curl -I https://auth.homelab.local
```

### Rotate Logs

Traefik logs are in `data/traefik/logs/`. Rotate them periodically:

```bash
# Compress old logs
gzip data/traefik/logs/traefik.log.1
gzip data/traefik/logs/access.log.1

# Delete logs older than 30 days
find data/traefik/logs/ -name "*.gz" -mtime +30 -delete
```

### Renew Certificates

Traefik automatically renews Let's Encrypt certificates 30 days before expiry. Check certificate status:

```bash
# View ACME storage
cat data/traefik/acme.json | jq '.cloudflare.Certificates[] | {domain: .domain, expiry: .notAfter}'
```

## Security Hardening

### 1. Firewall Rules (UniFi/pfSense)

```bash
# Allow only necessary ports from WAN
ALLOW: WAN → 10.10.10.10:80,443 (HTTP/HTTPS)
DENY: WAN → 10.10.10.10:* (Everything else)

# Allow DNS from homelab only
ALLOW: 10.10.0.0/16 → 10.10.10.10:53 (DNS)
DENY: * → 10.10.10.10:53
```

### 2. Fail2Ban for Traefik (Optional)

Install Fail2Ban to block brute force attacks:

```bash
# /etc/fail2ban/filter.d/traefik-auth.conf
[Definition]
failregex = ^.*"RemoteAddr":"<HOST>".*"RequestMethod":"POST".*"RequestPath":"/api/.*".*"DownstreamStatus":401
ignoreregex =

# /etc/fail2ban/jail.local
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /path/to/data/traefik/logs/access.log
maxretry = 5
bantime = 3600
```

### 3. Rate Limiting

Already configured in `config/traefik/dynamic/authentik.yml`:
- 100 requests per minute average
- 50 burst capacity

### 4. Security Headers

All routes have security headers applied:
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Strict-Transport-Security: max-age=31536000
- X-XSS-Protection: 1; mode=block

### 5. Authentik Security

- Enable MFA for all admin accounts
- Use strong passwords (12+ characters)
- Enable audit logging
- Review access logs regularly
- Limit failed login attempts

## Troubleshooting

### Traefik not routing to services

```bash
# Check Traefik logs
docker compose logs traefik

# Verify dynamic config is loaded
docker exec traefik cat /dynamic/authentik.yml

# Check if service is reachable from Traefik
docker exec traefik ping 10.10.12.10
```

### DNS not resolving

```bash
# Test DNS from another machine
dig @10.10.10.10 example.com
nslookup example.com 10.10.10.10

# Check AdGuard logs
docker compose logs adguard

# Verify AdGuard is listening
netstat -tlnp | grep 53
```

### Authentik not authenticating

```bash
# Check Authentik logs
docker compose logs authentik-server authentik-worker

# Verify database connection
docker exec authentik-server authentik check_outpost_health

# Check Redis connection
docker exec authentik-server redis-cli -h 10.10.11.10 -p 6379 --tls --no-auth-warning -a PASSWORD PING
```

### Certificate issues

```bash
# Check ACME logs
docker compose logs traefik | grep acme

# Verify Cloudflare API token
docker exec traefik env | grep CF_

# Manual certificate request
docker exec traefik traefik cert check
```

## Monitoring Integration

This VM exports metrics for Prometheus (VM 3):

**Traefik Metrics:** `http://10.10.10.10:8080/metrics`

Add to Prometheus config:
```yaml
- job_name: 'traefik'
  static_configs:
    - targets: ['10.10.10.10:8080']
```

## Migration from LXCs

If migrating from existing LXCs:

1. **Export current Traefik config:** Backup existing routing rules
2. **Export AdGuard settings:** Settings → General Settings → Export
3. **Export Authentik data:** Use Authentik backup command
4. **Deploy new VM1:** Follow setup instructions above
5. **Import configurations:** Restore exported data
6. **Update DNS:** Point clients to new AdGuard IP
7. **Test thoroughly:** Verify all routes work before decommissioning LXCs

## Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdguardHome/wiki)
- [Authentik Documentation](https://goauthentik.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
