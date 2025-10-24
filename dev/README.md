# Dev VM - Development Stack

**VM:** 10.10.10.114
**Purpose:** Git hosting, container registry, CI/CD, and deployment platform

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Gitea | 3000 (HTTP), 222 (SSH) | Git hosting + Container Registry + Gitea Actions |
| act_runner | - | Executes Gitea Actions workflows |
| Dokploy | 3200 | Deployment platform (installed separately) |

## Quick Start

### Prerequisites

1. **PostgreSQL Database on db host (10.10.10.111)**
   ```bash
   # SSH to db VM and create Gitea database
   docker exec -it postgres psql -U postgres
   CREATE DATABASE gitea;
   CREATE USER gitea WITH PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;
   \q
   ```

2. **1Password Secrets**
   Create these items in 1Password vault "Server":

   **Item: `gitea-db`**
   - Field: `password` (PostgreSQL password from above)

   **Item: `gitea`**
   - Field: `secret_key` (generate: `openssl rand -base64 50`)
   - Field: `internal_token` (generate: `openssl rand -hex 105`)
   - Field: `runner_token` (will be added after Gitea setup)

3. **Update `.env` file**
   - Change `DOMAIN=yourdomain.com` to your actual domain

### Deployment

```bash
# SSH to dev VM (10.10.10.114)
cd /opt/homelab

# Deploy Gitea (act_runner will fail first time - that's expected)
op run --env-file=.env -- docker compose up -d gitea

# Wait for Gitea to start
docker compose logs -f gitea

# Access Gitea at http://10.10.10.114:3000
# Complete the initial setup wizard (it will detect existing config)
```

### Initial Gitea Configuration

1. **Access Gitea:** http://10.10.10.114:3000
2. **Create admin account** (first user becomes admin)
3. **Enable Actions:**
   - Go to: Site Administration → Configuration → Actions
   - Verify `ENABLED = true`
4. **Get Runner Token:**
   - Settings → Actions → Runners
   - Click "Create new Runner"
   - Copy the registration token
   - Add to 1Password: `op://Server/gitea/runner_token`

5. **Deploy act_runner:**
   ```bash
   op run --env-file=.env -- docker compose up -d act-runner
   ```

6. **Verify runner is connected:**
   - Settings → Actions → Runners
   - Should see "homelab-runner" with green status

### Container Registry Setup

Gitea container registry is automatically enabled. To use it:

```bash
# Login to registry
docker login git.yourdomain.com

# Tag and push image
docker tag myapp:latest git.yourdomain.com/username/myapp:latest
docker push git.yourdomain.com/username/myapp:latest
```

### Dokploy Installation

Dokploy uses its own installer (not docker-compose):

```bash
# SSH to dev VM
curl -sSL https://dokploy.com/install.sh | sh
```

This will:
- Install Dokploy on port 3200
- Set up its own Traefik instance
- Create systemd service

## Gitea Actions Workflow Example

Create `.gitea/workflows/build.yml` in your repo:

```yaml
name: Build and Push Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to Gitea Registry
        uses: docker/login-action@v3
        with:
          registry: git.yourdomain.com
          username: ${{ gitea.actor }}
          password: ${{ secrets.GITEA_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: git.yourdomain.com/${{ gitea.repository }}:${{ gitea.sha }}
```

## Repository Mirroring

### Mirror GitHub → Gitea (Pull)

1. In Gitea: New Migration → GitHub
2. Enter GitHub repo URL
3. Check "This repository will be a mirror"
4. Gitea will sync automatically

### Mirror Gitea → GitHub (Push)

1. Create GitHub personal access token (repo permissions)
2. In Gitea repo: Settings → Repository → Mirrors
3. Add push mirror: https://github.com/username/repo.git
4. Enter GitHub username + token
5. Enable "Sync on push"

## Troubleshooting

### act_runner not connecting

```bash
# Check runner logs
docker compose logs -f act-runner

# Verify runner token is correct
op read "op://Server/gitea/runner_token"

# Restart runner
docker compose restart act-runner
```

### PostgreSQL connection failed

```bash
# Test connection from dev VM
docker run --rm -it postgres:16-alpine psql -h 10.10.10.111 -U gitea -d gitea

# Check PostgreSQL logs on db VM
docker compose logs -f postgres
```

### Container registry authentication failed

```bash
# Generate Gitea access token
# Settings → Applications → Generate New Token
# Scope: package:write

# Login with token
docker login git.yourdomain.com -u username -p <token>
```

## Monitoring

- **Grafana:** View Gitea logs in centralized Loki
- **Beszel:** Monitor dev VM resources at http://10.10.10.112:8090

## Access URLs (via Traefik on edge VM)

- **Gitea:** https://git.yourdomain.com
- **Dokploy:** https://deploy.yourdomain.com
- **Container Registry:** git.yourdomain.com (Docker registry endpoint)
