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
if op item get postgres --vault="$VAULT" >/dev/null 2>&1; then
    echo "  Item 'postgres' already exists (skipping)"
else
    op item create --category=database --title=postgres \
      --vault="$VAULT" \
      username=postgres \
      password="$(openssl rand -base64 32)"
    echo "  ✓ Created postgres"
fi

# MongoDB
echo "Creating mongodb item..."
if op item get mongodb --vault="$VAULT" >/dev/null 2>&1; then
    echo "  Item 'mongodb' already exists (skipping)"
else
    op item create --category=database --title=mongodb \
      --vault="$VAULT" \
      username=root \
      password="$(openssl rand -base64 32)"
    echo "  ✓ Created mongodb"
fi

# Redis
echo "Creating redis item..."
if op item get redis --vault="$VAULT" >/dev/null 2>&1; then
    echo "  Item 'redis' already exists (skipping)"
else
    op item create --category=password --title=redis \
      --vault="$VAULT" \
      password="$(openssl rand -base64 32)"
    echo "  ✓ Created redis"
fi

# MinIO
echo "Creating minio item..."
if op item get minio --vault="$VAULT" >/dev/null 2>&1; then
    echo "  Item 'minio' already exists, updating fields..."
    op item edit minio --vault="$VAULT" \
      'domain[text]=s3.homelab.local' \
      'server_url[text]=https://s3.homelab.local' \
      'console_url[text]=https://minio-console.homelab.local' 2>/dev/null || true
else
    op item create --category=login --title=minio \
      --vault="$VAULT" \
      username=minioadmin \
      password="$(openssl rand -base64 32)"
    echo "  ✓ Created minio"

    # Add custom fields
    op item edit minio --vault="$VAULT" \
      'domain[text]=s3.homelab.local' \
      'server_url[text]=https://s3.homelab.local' \
      'console_url[text]=https://minio-console.homelab.local'
    echo "  ✓ Added minio custom fields"
fi

echo
echo "✓ All secrets created successfully!"
echo
echo "Items in vault '$VAULT':"
op item list --vault="$VAULT" --format=json | jq -r '.[] | "  - \(.title)"'
echo
echo "To verify secrets are working, run:"
echo "  op inject -i docker-compose.yml | head -n 20"
