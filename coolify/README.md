# Coolify - Self-Hosted PaaS

Deploy web applications with git-based workflows.

## Overview

**VM Name:** coolify
**IP Address:** 10.10.10.114
**Resources:** 8GB RAM, 4 CPU cores, 100GB storage
**Network:** VLAN 10 (Trusted)

## What is Coolify?

Coolify is a self-hosted Platform-as-a-Service (PaaS) like Heroku/Vercel/Netlify:

- Deploy from GitHub/GitLab with git push
- Automatic SSL certificates
- Built-in monitoring and logging
- Support for Docker, Node.js, PHP, Python, Ruby, etc.
- Databases, Redis, S3 storage
- Staging and production environments

## Installation

Coolify uses its own installer (not docker-compose).

### 1. Prepare VM

```bash
# SSH to coolify VM
ssh coolify-vm

# Update system
sudo apt update && sudo apt upgrade -y

# Ensure Docker is installed
docker --version
```

### 2. Install Coolify

```bash
# Run official installer
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

The installer will:
- Install Coolify and dependencies
- Set up networking
- Start Coolify services
- Generate SSL certificates

### 3. Access Coolify

**URL:** http://10.10.10.114:8000

Or via Traefik: https://coolify.homelab.example.com

**Initial Setup:**
1. Create admin account
2. Set up email (optional)
3. Add SSH keys for git deployments
4. Configure domains

### 4. Connect to Data Tier

When deploying apps that need databases, connect to your data VM:

**PostgreSQL:**
```
Host: 10.10.10.111
Port: 5432
Database: your_app
User: your_app
Password: (from 1Password)
```

**MongoDB:**
```
Host: 10.10.10.111
Port: 27017
```

**Redis:**
```
Host: 10.10.10.111
Port: 6379
```

## Deploying Your First App

### Example: Next.js App

1. **Add Git Source:**
   - Settings → Sources → Add GitHub/GitLab
   - Authenticate and select repository

2. **Create Project:**
   - Projects → New Project
   - Select your repository
   - Choose branch (main/production)

3. **Configure:**
   - Set build command: `npm run build`
   - Set start command: `npm start`
   - Set port: `3000`
   - Add environment variables

4. **Add Domain:**
   - Custom domain: `myapp.homelab.example.com`
   - Coolify automatically configures SSL

5. **Deploy:**
   - Click "Deploy"
   - Watch build logs
   - Access your app!

### Auto-Deploy on Git Push

Once configured, Coolify automatically deploys when you push to your branch:

```bash
git push origin main
# Coolify detects push → builds → deploys → live!
```

## Use Cases

**Perfect for:**
- Personal projects and demos
- Internal tools and dashboards
- Staging environments
- Learning/experimenting

**Not ideal for:**
- High-scale production (use Kubernetes)
- Multi-region deployments
- Complex microservices (use docker-compose directly)

## Management

**Komodo:** http://10.10.10.112:9120
- You'll see Coolify's containers there
- Don't manage them directly - use Coolify UI

**Coolify Dashboard:** http://10.10.10.114:8000
- Deploy apps
- View logs
- Manage databases
- Configure domains

## Connecting to External Services

### Use Data Tier Databases

Instead of creating databases in Coolify, use your data VM:

**In Coolify Environment Variables:**
```
DATABASE_URL=postgresql://myapp:password@10.10.10.111:5432/myapp
REDIS_URL=redis://:password@10.10.10.111:6379
MONGODB_URL=mongodb://myapp:password@10.10.10.111:27017/myapp
```

**Benefits:**
- Centralized backups
- Shared across environments
- Better resource utilization

## Updating Coolify

```bash
# SSH to coolify VM
ssh coolify-vm

# Run update script
curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh | bash
```

## Troubleshooting

**Can't access Coolify:**
```bash
# Check if running
docker ps | grep coolify

# Check logs
docker logs coolify

# Restart
systemctl restart coolify
```

**Deployments failing:**
- Check build logs in Coolify UI
- Verify environment variables
- Check disk space: `df -h`

## Next Steps

1. ✅ **Coolify installed**
2. 🚧 **Deploy your first app**
3. 🚧 **Connect to databases on data VM**
4. 🚧 **Set up CI/CD with GitHub**

---

**Install:** Run Coolify installer script
**Access:** http://10.10.10.114:8000
**Deploy:** git push → automatic deployment!
