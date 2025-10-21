# Edge VM Deployment Instructions

## Summary of Changes

Fixed Cloudflare certificate issues by:
1. Changed all service domains from `*.homelab.local` → `*.onurx.com`
2. Added routers for Portainer and Authentik
3. Configured wildcard certificate: `*.onurx.com`
4. Setup AdGuard DNS rewrites (see ADGUARD-DNS-SETUP.md)

## Deploy on Edge VM (10.10.10.110)

### 1. Commit and Push Changes (Proxmox Host)

```bash
cd /flash/docker/homelab
git add edge/
git commit -m "Fix Traefik certificate config - use *.onurx.com with Cloudflare"
git push
```

### 2. SSH to Edge VM

```bash
ssh root@10.10.10.110
cd /opt/homelab
```

### 3. Remove Old Certificate Data

```bash
# Stop Traefik
docker compose down traefik

# Remove old acme.json (if exists) to force fresh certificate request
rm -f traefik/data/acme.json

# Create data directory structure
mkdir -p traefik/data/logs
```

### 4. Deploy Traefik

```bash
op run --env-file=.env -- docker compose up -d traefik
```

### 5. Check Certificate Acquisition

```bash
# Watch logs for certificate generation
docker compose logs -f traefik

# Look for:
# "Requesting certificate for *.onurx.com"
# "Cloudflare DNS challenge"
# "Certificate obtained successfully"

# Check acme.json was created (should be ~600 permissions)
ls -la traefik/data/acme.json

# View certificate details
docker compose exec traefik cat /data/acme.json | jq '.cloudflare.Certificates[0].domain'
```

### 6. Verify Traefik Dashboard

```bash
# Check container health
docker compose ps traefik

# Access dashboard
curl http://10.10.10.110:8080/dashboard/

# Or open in browser: http://10.10.10.110:8080
```

### 7. Check for Errors

```bash
# If certificate fails, check:
docker compose logs traefik | grep -i error
docker compose logs traefik | grep -i cloudflare

# Common issues:
# - Invalid Cloudflare API token
# - DNS propagation delays
# - Rate limiting from Let's Encrypt
```

## Expected Results

- `traefik/data/acme.json` created with certificate
- Traefik dashboard accessible at `http://10.10.10.110:8080`
- Logs show successful certificate acquisition
- Wildcard cert for `*.onurx.com` obtained

## Next Steps

1. **Deploy AdGuard** - see ADGUARD-DNS-SETUP.md
2. **Deploy Authentik** - requires PostgreSQL + Redis from db host
3. **Test service access** - `https://portainer.onurx.com`

## Troubleshooting

### Certificate Not Generating

```bash
# Check Cloudflare credentials
op run --env-file=.env -- env | grep CF_

# Verify 1Password access
op read "op://Server/cloudflare/api_token"

# Check DNS resolution
nslookup onurx.com 1.1.1.1
```

### acme.json Permission Issues

```bash
# Traefik creates this file automatically
# If manually created, set correct permissions:
chmod 600 traefik/data/acme.json
chown root:root traefik/data/acme.json
```

### Cloudflare API Errors

- Verify token has `Zone:DNS:Edit` permissions
- Check token is for correct zone (onurx.com)
- Ensure email matches Cloudflare account: onur03@gmail.com
