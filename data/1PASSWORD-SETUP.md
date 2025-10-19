# 1Password Setup Guide for Data Tier

This guide helps you set up the required secrets in your 1Password vault named `Server`.

## Required 1Password Items

You need to create 4 items in your `Server` vault:

### 1. PostgreSQL (`postgres`)

**Item Type:** Database or Login

**Required Fields:**
- `username` → postgres
- `password` → (generate strong password)

**How to create:**
```bash
# Using 1Password CLI
op item create --category=database --title=postgres \
  --vault=Server \
  username=postgres \
  password=$(openssl rand -base64 32)
```

### 2. MongoDB (`mongodb`)

**Item Type:** Database or Login

**Required Fields:**
- `username` → root
- `password` → (generate strong password)

**How to create:**
```bash
# Using 1Password CLI
op item create --category=database --title=mongodb \
  --vault=Server \
  username=root \
  password=$(openssl rand -base64 32)
```

### 3. Redis (`redis`)

**Item Type:** Database or Login

**Required Fields:**
- `password` → (generate strong password)

**How to create:**
```bash
# Using 1Password CLI
op item create --category=database --title=redis \
  --vault=Server \
  password=$(openssl rand -base64 32)
```

### 4. MinIO (`minio`)

**Item Type:** Database or Login

**Required Fields:**
- `username` → minioadmin (or your choice)
- `password` → (generate strong password)
- `domain` → s3.homelab.local
- `server_url` → https://s3.homelab.local
- `console_url` → https://minio-console.homelab.local

**How to create:**
```bash
# Using 1Password CLI
op item create --category=login --title=minio \
  --vault=Server \
  username=minioadmin \
  password=$(openssl rand -base64 32) \
  domain=s3.homelab.local \
  'server_url=https://s3.homelab.local' \
  'console_url=https://minio-console.homelab.local'
```

## Automated Setup Script

Save this as `setup-1password-secrets.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Check if OP_SERVICE_ACCOUNT_TOKEN is set
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    echo "Error: OP_SERVICE_ACCOUNT_TOKEN not set"
    echo "Run: export OP_SERVICE_ACCOUNT_TOKEN='ops_your_token'"
    exit 1
fi

VAULT="Server"

echo "Creating secrets in 1Password vault: $VAULT"
echo

# PostgreSQL
echo "Creating postgres item..."
op item create --category=database --title=postgres \
  --vault="$VAULT" \
  username=postgres \
  password="$(openssl rand -base64 32)" 2>/dev/null || echo "Item 'postgres' already exists (skipping)"

# MongoDB
echo "Creating mongodb item..."
op item create --category=database --title=mongodb \
  --vault="$VAULT" \
  username=root \
  password="$(openssl rand -base64 32)" 2>/dev/null || echo "Item 'mongodb' already exists (skipping)"

# Redis
echo "Creating redis item..."
op item create --category=password --title=redis \
  --vault="$VAULT" \
  password="$(openssl rand -base64 32)" 2>/dev/null || echo "Item 'redis' already exists (skipping)"

# MinIO
echo "Creating minio item..."
op item create --category=login --title=minio \
  --vault="$VAULT" \
  username=minioadmin \
  password="$(openssl rand -base64 32)" 2>/dev/null || echo "Item 'minio' already exists (skipping)"

# Add custom fields to minio
op item edit minio --vault="$VAULT" \
  domain=s3.homelab.local \
  'server_url=https://s3.homelab.local' \
  'console_url=https://minio-console.homelab.local' 2>/dev/null || true

echo
echo "✓ All secrets created successfully!"
echo
echo "To view secrets:"
echo "  op item list --vault=$VAULT"
echo
echo "To view a specific secret:"
echo "  op item get postgres --vault=$VAULT"
```

Make it executable:
```bash
chmod +x setup-1password-secrets.sh
./setup-1password-secrets.sh
```

## Verify Setup

Check that all items were created:

```bash
# List all items in Server vault
op item list --vault=Server

# Get specific values
op read "op://Server/postgres/password"
op read "op://Server/mongodb/username"
op read "op://Server/redis/password"
op read "op://Server/minio/username"
```

## Testing Secret Injection

Before deploying, test that secret injection works:

```bash
# Test injection (dry run)
op inject -i docker-compose.yml

# Should output the docker-compose with secrets replaced
```

If you see actual values instead of `op://` references, it's working!

## Deployment

Once secrets are set up, deploy with:

```bash
op inject -i docker-compose.yml | docker compose -f - up -d
```

## Updating Secrets

To update a secret:

```bash
# Update password
op item edit postgres --vault=Server password="new-password"

# Redeploy services
op inject -i docker-compose.yml | docker compose -f - up -d
```

## Troubleshooting

### "Item not found" errors

Make sure the vault name is exactly `Server` (case-sensitive):
```bash
op vault list
```

### "Field not found" errors

Check field names:
```bash
op item get postgres --vault=Server --format=json | jq '.fields'
```

### Permission errors

Verify your service account has access to the `Server` vault and can read items.

## Security Notes

1. **Never commit** actual secrets to git
2. **Service Account Token**: Keep `OP_SERVICE_ACCOUNT_TOKEN` secure
3. **Least Privilege**: Service account should only have read access to `Server` vault
4. **Audit Logs**: Check 1Password audit logs regularly for unauthorized access
