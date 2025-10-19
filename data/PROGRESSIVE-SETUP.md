# Progressive Setup Guide

Start with ONE service, test it, learn it, then add the next one.

## Phase 1: PostgreSQL Only (Start Here!)

### 1. Setup

```bash
# Generate ONLY PostgreSQL certificates
mkdir -p certs/postgres
cd certs/postgres

openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"

openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=postgres.homelab.local"

chmod 600 server.key ca.key
chmod 644 server.crt ca.crt

cd ../..
```

### 2. Create 1Password Secret

```bash
# Just postgres
op item create --category=database --title=postgres \
  --vault=Server \
  username=postgres \
  password=$(openssl rand -base64 32)
```

### 3. Deploy PostgreSQL

```bash
# Use the postgres-only compose file
op inject -i docker-compose.postgres-only.yml | docker compose -f - up -d

# Watch logs
docker compose logs -f postgres
```

### 4. Test It

```bash
# Connect to database
docker exec -it postgres psql -U postgres

# Inside psql:
\l                          # List databases
\du                         # List users
CREATE DATABASE test;       # Create test DB
\c test                     # Connect to test
CREATE TABLE users (id INT, name VARCHAR(50));
INSERT INTO users VALUES (1, 'Alice');
SELECT * FROM users;        # Should see Alice
\q                          # Quit
```

### 5. Learn & Modify

Now play with it:
- Try different PostgreSQL settings in `config/postgres/postgresql.conf`
- Test connections from other machines
- Try creating databases for your apps
- Check the logs: `docker compose logs postgres`
- Check resource usage: `docker stats postgres`

**Once you're comfortable, move to Phase 2.**

---

## Phase 2: Add MongoDB

### 1. Generate MongoDB Certificates

```bash
cd certs
mkdir -p mongodb
cd mongodb

openssl req -new -x509 -days 3650 -nodes -text \
  -out ca.crt -keyout ca.key \
  -subj "/CN=Homelab CA"

openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=mongodb.homelab.local"

# MongoDB needs combined PEM
cat server.key server.crt > server.pem

chmod 600 server.pem server.key ca.key
chmod 644 server.crt ca.crt

cd ../..
```

### 2. Create 1Password Secret

```bash
op item create --category=database --title=mongodb \
  --vault=Server \
  username=root \
  password=$(openssl rand -base64 32)
```

### 3. Add MongoDB to docker-compose.yml

Open `docker-compose.yml` and **uncomment** the MongoDB section (or copy it from `docker-compose.full.yml`).

### 4. Deploy

```bash
./dc up -d
./dc logs -f mongodb
```

### 5. Test MongoDB

```bash
docker exec -it mongodb mongosh -u root -p
# Enter password from 1Password
# use admin
# show dbs
```

---

## Phase 3: Add Redis

Same pattern:
1. Generate certs
2. Create 1Password secret
3. Add to docker-compose.yml
4. Deploy
5. Test

---

## Phase 4: Add MinIO

Same pattern as above.

---

## Progressive Approach Benefits

✅ **Learn as you go** - Understand each service before adding the next
✅ **Easy troubleshooting** - Only one new thing to debug at a time
✅ **Lower resource usage** - Start small, scale up
✅ **Faster iterations** - Test changes quickly
✅ **Build confidence** - Each working service is a win

## Quick Commands

```bash
# Start with just postgres
op inject -i docker-compose.postgres-only.yml | docker compose -f - up -d

# Later, use the full file
./dc up -d

# View status
docker compose ps

# View logs for specific service
docker compose logs -f postgres

# Stop everything
docker compose down
```

## Tips

1. **Start simple** - Just PostgreSQL first
2. **Test thoroughly** - Make sure it works before moving on
3. **Take your time** - No rush to add everything
4. **Modify configs** - Change settings, see what happens
5. **Break things** - It's a homelab! Learn by experimenting

**You don't need all 4 databases running to start learning!**
