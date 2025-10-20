# VM Template Setup

Create a reusable VM template in Proxmox with all prerequisites installed and configured.

## Why Use a Template?

Instead of manually configuring each VM, create one template with everything pre-installed:
- ✅ Ubuntu Server
- ✅ Docker + Docker Compose
- ✅ Git (configured)
- ✅ 1Password CLI
- ✅ Common tools (curl, wget, vim, htop, etc.)

Then clone the template to create new VMs instantly!

---

## Creating the Template

### 1. Create Base VM in Proxmox

```bash
# Download Ubuntu Server 24.04 LTS ISO
# In Proxmox web UI:
# - Create new VM
# - Name: ubuntu-docker-template
# - RAM: 2GB (minimum for setup)
# - Disk: 32GB
# - Boot from Ubuntu ISO
```

### 2. Install Ubuntu Server

- Choose "Ubuntu Server (minimized)"
- Username: `homelab`
- Enable OpenSSH server
- Complete installation and reboot

### 3. SSH into the VM

```bash
ssh homelab@<vm-ip>
```

### 4. Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 5. Install Essential Tools

```bash
sudo apt install -y \
  curl \
  wget \
  vim \
  htop \
  net-tools \
  git \
  nfs-common \
  ca-certificates \
  gnupg \
  lsb-release
```

### 6. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker homelab

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify
docker --version
```

### 7. Configure Git

**THIS IS THE KEY STEP YOU WERE ASKING ABOUT!**

```bash
git config --global user.name "XVll"
git config --global user.email "onur03@gmail.com"
git config --global init.defaultBranch main

# Verify configuration
git config --list
```

### 8. Install 1Password CLI

```bash
# Download and install 1Password CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list

sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
  sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol

sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

sudo apt update && sudo apt install -y 1password-cli

# Verify
op --version
```

**IMPORTANT:** Do NOT set `OP_SERVICE_ACCOUNT_TOKEN` in the template! This is a secret that should be configured per-VM after cloning.

### 9. Install QEMU Guest Agent

```bash
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

### 10. Clean Up

```bash
# Remove SSH host keys (will be regenerated on first boot)
sudo rm -f /etc/ssh/ssh_host_*

# Clean package cache
sudo apt clean
sudo apt autoremove -y

# Clear bash history
cat /dev/null > ~/.bash_history
history -c

# Clear machine-id (will be regenerated)
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

### 11. Shutdown VM

```bash
sudo shutdown -h now
```

---

## Convert to Template in Proxmox

In Proxmox web UI:

1. Right-click the VM → **Convert to Template**
2. Confirm the conversion

That's it! Your template is ready.

---

## Creating VMs from Template

### Clone Type: Full Clone vs Linked Clone

**Use Full Clone (Recommended):**
- ✅ Independent VM with its own disk
- ✅ Better performance
- ✅ Can delete template later
- ✅ Template corruption won't affect VMs
- ❌ Uses more disk space
- ❌ Takes longer to create

**Linked Clone (Not Recommended for Production):**
- ❌ Depends on template disk (can't delete template)
- ❌ Slower performance
- ❌ All VMs fail if template disk fails
- ✅ Saves disk space
- ✅ Faster to create

**For homelab production services → Use Full Clone**

### Method 1: Proxmox Web UI

1. Right-click template → **Clone**
2. Mode: **Full Clone** (recommended)
3. Name: `data` (or `edge`, `observability`, `media`)
4. VM ID: Auto
5. Click **Clone**

### Method 2: Command Line

```bash
# Clone template (ID 9000) to new VM
qm clone 9000 111 --name data --full

# Customize resources
qm set 111 --memory 10240 --cores 4

# Set static IP (optional)
qm set 111 --ipconfig0 ip=10.10.10.111/24,gw=10.10.10.1

# Start VM
qm start 111
```

---

## First Boot of Cloned VM

After cloning and starting a VM:

### 1. SSH into the new VM

```bash
ssh homelab@10.10.10.111
```

### 2. Set hostname

```bash
sudo hostnamectl set-hostname data
```

### 3. Update /etc/hosts

```bash
echo "127.0.1.1 data" | sudo tee -a /etc/hosts
```

### 4. Regenerate SSH host keys

```bash
sudo dpkg-reconfigure openssh-server
```

### 5. Set up SSH Key for Git (Private Repos Only)

**If your repository is private, you need SSH authentication:**

```bash
# Generate SSH key for this VM
ssh-keygen -t ed25519 -C "homelab-data-vm" -f ~/.ssh/id_ed25519 -N ""

# Display public key
cat ~/.ssh/id_ed25519.pub

# Copy the public key and add it to your GitHub/GitLab account:
# GitHub: Settings → SSH and GPG keys → New SSH key
# GitLab: Preferences → SSH Keys → Add new key
```

**Alternative: Use the same SSH key on all VMs**

```bash
# Copy your existing SSH key to the VM
# From your local machine:
scp ~/.ssh/id_ed25519 homelab@10.10.10.111:~/.ssh/
scp ~/.ssh/id_ed25519.pub homelab@10.10.10.111:~/.ssh/

# On the VM, set correct permissions:
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Note:** Do NOT put SSH keys in the template! Each VM should have its own key (or copy after cloning).

### 6. Set up 1Password Service Account Token

**IMPORTANT:** This is where you add the 1Password token (NOT in the template!)

```bash
# Get your service account token from 1Password
# Then add it to your shell profile:

echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"' >> ~/.bashrc
source ~/.bashrc

# Verify it works
op vault list
```

**Note:** You can use the same token on all VMs, but set it manually on each after cloning.

### 7. Clone infrastructure repository

```bash
cd /opt
sudo mkdir homelab
sudo chown homelab:homelab homelab

# For private repos, use SSH URL:
git clone git@github.com:yourusername/infrastructure-1.git homelab

# For public repos, HTTPS is fine:
# git clone https://github.com/yourusername/infrastructure-1.git homelab

cd homelab
```

**Note:** Git is already configured! No need to run `git config` again!

### 8. Deploy services

Follow the specific VM guide (data, edge, observability, media).

---

## Benefits of Using Templates

✅ **Consistent environment** - All VMs have the same base configuration
✅ **Faster deployment** - Clone in seconds instead of hours
✅ **Git pre-configured** - No need to configure git on each VM
✅ **Docker ready** - Pre-installed and configured
✅ **1Password CLI ready** - Just set the token and go
✅ **Easy updates** - Update template, create new VMs from it

---

## Template Maintenance

### Updating the Template

When you need to update the base image:

1. Clone the template to a temporary VM
2. Boot it up
3. Make updates (apt upgrade, new packages, etc.)
4. Clean up (step 10 above)
5. Shutdown
6. Delete old template
7. Convert new VM to template

### Version Your Templates

Good practice:
- `ubuntu-docker-template-v1`
- `ubuntu-docker-template-v2`
- Keep old versions until all VMs migrated

---

## Summary

**Create template once:**
```bash
# Install Ubuntu + Docker + Git + 1Password CLI
# Configure git globally (with your real name/email!)
# DO NOT set OP_SERVICE_ACCOUNT_TOKEN
# Convert to template
```

**Create VMs instantly (Full Clone):**
```bash
# Clone template (Full Clone mode)
# Set hostname
# Set up SSH key for git (if private repo)
# Set OP_SERVICE_ACCOUNT_TOKEN
# Clone repo
# Deploy services
```

**What's pre-configured in template:**
- ✅ Git installed (with your name/email for commits)
- ✅ Docker
- ✅ 1Password CLI installed

**What you set per-VM after cloning:**
- ❌ SSH key for git (if private repo)
- ❌ 1Password token

**Git name/email already configured!** 🎉

No more manual git config on every VM!
