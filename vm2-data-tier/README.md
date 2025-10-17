# VM 2: Data Tier

Isolated database and storage layer for the homelab infrastructure.

## Overview

**VLAN:** 11 (10.10.11.0/24)
**IP Address:** 10.10.11.10
**Resources:** 10GB RAM, 4 CPU cores, 100GB storage
**Security:** No internet access, firewall-controlled ingress only

## Services

| Service | Port | IP | Purpose |
|---------|------|-----|---------|
| PostgreSQL | 5432 | 10.10.11.11 | Relational database |
| MongoDB | 27017 | 10.10.11.12 | Document database |
| Redis | 6379 (TLS: 6380) | 10.10.11.13 | Cache & message broker |
| MinIO | 9000/9001 | 10.10.11.14 | S3 object storage |

## Initial Setup

### 1. Generate TLS Certificates

Before deploying, generate self-signed certificates for each service:

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

# MongoDB certificates (requires combined PEM)
cd ../mongodb
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=mongodb.homelab.local"
cat server.key server.crt > server.pem
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"
chmod 600 server.pem server.key ca.key
chmod 644 server.crt ca.crt

# Redis certificates
cd ../redis
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=redis.homelab.local"
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"
chmod 600 server.key ca.key
chmod 644 server.crt ca.crt

# MinIO certificates
cd ../minio
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=s3.homelab.local"
openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"
chmod 600 server.key ca.key
chmod 644 server.crt ca.crt
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
# Edit .env with strong passwords using: openssl rand -base64 32
```

### 3. Deploy Services

```bash
docker compose up -d
docker compose logs -f
```

### 4. Initialize Databases

```bash
# Create PostgreSQL databases for applications
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

# Verify MongoDB
docker exec -it mongodb mongosh -u root -p
# use admin
# show dbs

# Verify Redis
docker exec -it redis redis-cli --tls --cert /certs/server.crt --key /certs/server.key --cacert /certs/ca.crt
# AUTH your_redis_password
# PING
# INFO

# Configure MinIO buckets
docker exec -it minio mc alias set local http://localhost:9000 minioadmin YOUR_PASSWORD
docker exec -it minio mc mb local/backups
docker exec -it minio mc mb local/media
docker exec -it minio mc mb local/documents
```

## Connection Strings

### PostgreSQL

```bash
# From VM 1 (Authentik)
postgresql://authentik:PASSWORD@10.10.11.10:5432/authentik?sslmode=require

# From VM 4 (n8n)
postgresql://n8n:PASSWORD@10.10.11.10:5432/n8n?sslmode=require

# From VM 4 (Paperless)
postgresql://paperless:PASSWORD@10.10.11.10:5432/paperless?sslmode=require
```

### MongoDB

```bash
mongodb://root:PASSWORD@10.10.11.10:27017/?tls=true&tlsAllowInvalidCertificates=true
```

### Redis

```bash
rediss://:PASSWORD@10.10.11.10:6379?ssl_cert_reqs=none
```

### MinIO (S3)

```bash
Endpoint: https://s3.homelab.local:9000
Access Key: minioadmin
Secret Key: YOUR_PASSWORD
Region: us-east-1
```

## Backup Strategy

### Automated Backups

Create a backup script at `/usr/local/bin/backup-data-tier.sh`:

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# PostgreSQL backup (all databases)
docker exec postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgres/postgres_all_$DATE.sql.gz"

# MongoDB backup (all databases)
docker exec mongodb mongodump --uri="mongodb://root:$MONGO_ROOT_PASSWORD@localhost:27017" \
  --out="/backups/mongodb_$DATE" --gzip

# Redis backup (RDB snapshot)
docker exec redis redis-cli --tls --cert /certs/server.crt --key /certs/server.key \
  --cacert /certs/ca.crt -a "$REDIS_PASSWORD" SAVE
cp data/redis/dump.rdb "backups/redis/dump_$DATE.rdb"

# MinIO backup (sync to external location)
docker exec minio mc mirror local/backups /backups/minio/$DATE

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

Schedule with cron:
```bash
# Daily at 2 AM
0 2 * * * /usr/local/bin/backup-data-tier.sh >> /var/log/backup-data-tier.log 2>&1
```

### Restore Procedures

```bash
# Restore PostgreSQL
gunzip -c backups/postgres/postgres_all_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i postgres psql -U postgres

# Restore MongoDB
docker exec mongodb mongorestore --uri="mongodb://root:PASSWORD@localhost:27017" \
  --gzip /backups/mongodb_YYYYMMDD_HHMMSS

# Restore Redis
docker compose stop redis
cp backups/redis/dump_YYYYMMDD_HHMMSS.rdb data/redis/dump.rdb
docker compose start redis
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

# Check logs
docker compose logs --tail=100 -f

# Check resource usage
docker stats
```

### Database Maintenance

```bash
# PostgreSQL - Vacuum and analyze
docker exec postgres psql -U postgres -c "VACUUM ANALYZE;"

# PostgreSQL - Check database sizes
docker exec postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"

# MongoDB - Check database stats
docker exec mongodb mongosh --eval "db.stats()" -u root -p

# Redis - Check memory usage
docker exec redis redis-cli --tls --cert /certs/server.crt --key /certs/server.key --cacert /certs/ca.crt -a PASSWORD INFO memory

# MinIO - Check storage usage
docker exec minio mc admin info local
```

## Security Considerations

1. **No Internet Access**: This VM should have firewall rules blocking all outbound internet traffic
2. **TLS Required**: All database connections must use TLS
3. **Firewall Rules**: Only allow connections from specific VMs/IPs (see pg_hba.conf)
4. **Strong Passwords**: Use 32+ character random passwords for all services
5. **Regular Updates**: Keep container images updated for security patches
6. **Backup Encryption**: Consider encrypting backups before sending offsite

## Troubleshooting

### PostgreSQL won't start
```bash
# Check logs
docker compose logs postgres

# Check certificate permissions
ls -la certs/postgres/

# Verify configuration
docker exec postgres cat /etc/postgresql/postgresql.conf
```

### MongoDB TLS issues
```bash
# Verify PEM file format
openssl x509 -in certs/mongodb/server.pem -text -noout

# Test connection
docker exec mongodb mongosh --tls --tlsAllowInvalidCertificates
```

### Redis TLS connection refused
```bash
# Check if TLS port is listening
docker exec redis netstat -tlnp

# Test local connection
docker exec redis redis-cli --tls --cert /certs/server.crt --key /certs/server.key --cacert /certs/ca.crt PING
```

### MinIO storage issues
```bash
# Check disk usage
docker exec minio df -h /data

# Check MinIO logs
docker compose logs minio

# Verify buckets
docker exec minio mc ls local/
```

## Monitoring Integration

This VM should be monitored by VM 3 (Observability) using:
- **Prometheus exporters**: postgres_exporter, mongodb_exporter, redis_exporter
- **Alloy agent**: For log collection
- **Uptime Kuma**: For service health checks

Connection endpoints for monitoring:
```bash
PostgreSQL: postgresql://monitoring:PASSWORD@10.10.11.10:5432/postgres
MongoDB: mongodb://monitoring:PASSWORD@10.10.11.10:27017
Redis: rediss://:PASSWORD@10.10.11.10:6379
MinIO: http://10.10.11.10:9000 (with read-only access key)
```
