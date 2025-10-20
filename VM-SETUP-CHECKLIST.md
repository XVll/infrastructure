# VM Setup Checklist

Quick guide to configure a fresh VM cloned from template.

## Prerequisites

- VM created from Debian template
- VirtioFS mounts configured in Proxmox:
  - `docker-{vmname}` → `/mnt/flash/docker/{vmname}`
  - `nas-backups` → `/mnt/nas/backups`
  - `nas-media` → `/mnt/nas/media` (media VM only)
  - `nas-downloads` → `/mnt/nas/downloads` (media VM only)
- Static IP assigned (see table below)

| VM Name | IP | VirtioFS Mounts |
|---------|-----|-----------------|
| db | 10.10.10.111 | docker-db, nas-backups |
| observability | 10.10.10.112 | docker-observability, nas-backups |
| edge | 10.10.10.110 | docker-edge |
| media | 10.10.10.113 | docker-media, nas-backups, nas-media, nas-downloads |
| coolify | 10.10.10.114 | docker-coolify, nas-backups |

---

## Step 1: First SSH Connection

```bash
# From your workstation
ssh fx@10.10.10.111  # Replace with your VM's IP

# If you get "host key changed" warning (normal after VM rebuild):
ssh-keygen -R 10.10.10.111
```

---

## Step 2: Set Hostname

```bash
# Set hostname (example: db, observability, edge, media, coolify)
sudo hostnamectl set-hostname db

# Verify
hostname
```

---

## Step 3: Create Home Directory

```bash
# Create home directory for fx user
sudo mkdir -p /home/fx
sudo chown fx:fx /home/fx
sudo cp /etc/skel/.bashrc /home/fx/
sudo cp /etc/skel/.profile /home/fx/
sudo chown fx:fx /home/fx/.bashrc /home/fx/.profile

# Go home
cd ~
pwd  # Should show /home/fx
```

---

## Step 4: Verify VirtioFS Mounts

```bash
# Check mounts exist
ls -la /mnt/flash/docker/
ls -la /mnt/nas/

# Verify your VM's mount
ls -la /mnt/flash/docker/db/  # Replace 'db' with your VM name

# If mounts are missing, check Proxmox VirtioFS configuration
```

---

## Step 5: Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y git curl wget vim htop net-tools

# Install Docker (if not in template)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose (if not in template)
sudo apt install -y docker-compose-plugin

# Install 1Password CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list

sudo apt update && sudo apt install -y 1password-cli

# Verify installations
docker --version
docker compose version
op --version
git --version

# Log out and back in for docker group to take effect
exit
```

---

## Step 6: Configure 1Password Service Account

```bash
# SSH back in
ssh fx@10.10.10.111

# Add 1Password service account token to bashrc
# Get your token from 1Password (starts with ops_...)
echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_YOUR_TOKEN_HERE"' >> ~/.bashrc

# Reload
source ~/.bashrc

# Create 1Password config directory
mkdir -p ~/.config/op

# Test it works
op read "op://Server/mongodb/username"
```

**Don't have a service account token yet?** See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md)

---

## Step 7: Clone Infrastructure Repo

```bash
# Navigate to the VirtioFS mount for this VM
cd /mnt/flash/docker/db  # Replace 'db' with your VM name

# Clone the repo
git clone https://github.com/YOUR_USERNAME/infrastructure-1.git .

# Or if already cloned, just pull latest
git pull

# Verify structure
ls -la
# Should see: docker-compose.yml, .env, mongodb/, postgres/, etc.
```

---

## Step 8: VM-Specific Setup

### For db VM (10.10.10.111)

```bash
cd /mnt/flash/docker/db

# Generate TLS certificates
bash generate-certs.sh

# Verify certificates created
ls -la mongodb/certs/
ls -la postgres/certs/

# Verify .env file has 1Password references
cat .env

# Test secret injection
op run --env-file=.env -- env | grep MONGODB

# Ready to deploy!
op run --env-file=.env -- docker compose up -d mongodb
```

### For observability VM (10.10.10.112)

```bash
cd /mnt/flash/docker/observability

# Verify .env file
cat .env

# Deploy Komodo first (requires MongoDB from db VM)
op run --env-file=.env -- docker compose up -d komodo

# Access Komodo UI: http://10.10.10.112:9120
```

### For edge VM (10.10.10.110)

```bash
cd /mnt/flash/docker/edge

# Deploy Traefik first
op run --env-file=.env -- docker compose up -d traefik

# Access Traefik dashboard
```

### For media VM (10.10.10.113)

```bash
cd /mnt/flash/docker/media

# Verify NAS mounts
ls /mnt/nas/media
ls /mnt/nas/downloads

# Deploy Jellyfin first
op run --env-file=.env -- docker compose up -d jellyfin
```

---

## Step 9: Verify Everything Works

```bash
# Check containers
docker ps

# Check logs
docker compose logs -f

# Check VirtioFS storage usage
df -h /mnt/flash/docker/

# Check NAS storage
df -h /mnt/nas/backups
```

---

## Quick Reference

### Common Commands

```bash
# Pull latest repo changes
cd /mnt/flash/docker/{vmname} && git pull

# Deploy a service
op run --env-file=.env -- docker compose up -d <service-name>

# View logs
docker compose logs -f <service-name>

# Restart a service
docker compose restart <service-name>

# Stop all services
docker compose down

# Update service images
docker compose pull
op run --env-file=.env -- docker compose up -d
```

### Directory Structure

```
/mnt/flash/docker/{vmname}/
├── docker-compose.yml
├── .env
├── {service}/
│   ├── data/       ← Service data (on VirtioFS/ZFS)
│   ├── config/     ← Configuration files
│   └── certs/      ← TLS certificates (generated)
└── /mnt/nas/backups/{service}/  ← Backups (NAS)
```

---

## Troubleshooting

### VirtioFS mount not showing up
- Check Proxmox hardware settings for VirtioFS devices
- Restart VM: `sudo reboot`
- Check dmesg: `dmesg | grep virtiofs`

### Docker permission denied
- Make sure user is in docker group: `groups | grep docker`
- Log out and back in after adding to group
- Or run: `newgrp docker`

### 1Password "not signed in"
- Check token is set: `echo $OP_SERVICE_ACCOUNT_TOKEN`
- Reload bashrc: `source ~/.bashrc`
- Test connection: `op vault list`

### Can't execute scripts
- Line ending issue: `sed -i 's/\r$//' script.sh`
- Make executable: `chmod +x script.sh`
- Or run with bash: `bash script.sh`

---

## Next Steps

Once your VM is configured:

1. ✅ Deploy first service
2. ✅ Check logs and verify it's healthy
3. ✅ Test connectivity from other VMs
4. ✅ Add next service (uncomment in docker-compose.yml)
5. ✅ Monitor in Komodo UI (once deployed)

See [README.md](README.md) for the progressive build strategy.
