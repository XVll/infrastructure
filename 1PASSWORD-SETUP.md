# 1Password Setup Guide

This guide shows you how to verify your 1Password secrets are correctly configured.

## Required 1Password Structure

You need to create these items in the **Server** vault:

### For Data Host (10.10.10.111)

1. **mongodb**
   - Field: `username` (e.g., `admin`)
   - Field: `password` (generate strong password)

2. **postgres**
   - Field: `username` (e.g., `postgres`)
   - Field: `password` (generate strong password)

3. **redis**
   - Field: `password` (generate strong password)

4. **minio**
   - Field: `username` (e.g., `admin`)
   - Field: `password` (generate strong password)

### For Observability Host (10.10.10.112)

5. **grafana**
   - Field: `username` (e.g., `admin`)
   - Field: `password` (generate strong password)

## Verify Your Setup

Run these commands to test that 1Password CLI can read your secrets:

```bash
# Test MongoDB credentials
op read "op://Server/mongodb/username"
op read "op://Server/mongodb/password"

# Test PostgreSQL credentials
op read "op://Server/postgres/username"
op read "op://Server/postgres/password"

# Test Redis password
op read "op://Server/redis/password"

# Test MinIO credentials
op read "op://Server/minio/username"
op read "op://Server/minio/password"

# Test Grafana credentials
op read "op://Server/grafana/username"
op read "op://Server/grafana/password"
```

If all commands return the expected values, you're ready to deploy!

## How It Works

1. Your `.env` files contain references like: `MONGODB_ROOT_USER=op://Server/mongodb/username`
2. When you run: `op run --env-file=.env -- docker compose up -d`
3. The `op run` command:
   - Reads your `.env` file
   - Finds all `op://...` references
   - Fetches the actual values from 1Password
   - Injects them as environment variables
   - Runs docker compose with the real values

## Benefits

✅ No plaintext passwords in files or git
✅ Easy password rotation (update in 1Password, redeploy)
✅ Audit trail of all secret access
✅ Works across all environments

## Troubleshooting

### "item not found" error

Make sure:
- You created the item in the **Server** vault (not a different vault)
- The item name matches exactly (e.g., `mongodb`, not `MongoDB`)
- Field names match exactly (e.g., `username`, not `Username`)

### "not signed in" error

Run: `op signin` or set your service account token:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
```

---

**You're all set!** Head back to [README.md](README.md) to start deploying.
