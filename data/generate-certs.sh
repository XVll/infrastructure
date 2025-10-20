#!/bin/bash
set -euo pipefail

echo "=== Data Tier TLS Certificate Generator ==="
echo

SERVICES=("postgres" "mongodb" "redis" "minio")

for service in "${SERVICES[@]}"; do
    echo "Generating certificates for $service..."

    CERT_DIR="$service/certs"
    mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"

    # Generate CA (Certificate Authority)
    if [ ! -f ca.key ]; then
        echo "  Creating CA..."
        openssl req -new -x509 -days 3650 -nodes -text \
          -out ca.crt -keyout ca.key \
          -subj "/CN=Homelab CA" \
          -addext "keyUsage = critical, digitalSignature, keyCertSign"
        chmod 600 ca.key
        chmod 644 ca.crt
    else
        echo "  CA already exists (skipping)"
    fi

    # Generate server certificate
    if [ ! -f server.key ]; then
        echo "  Creating server certificate..."

        # Determine CN based on service
        case $service in
            postgres)
                CN="postgres.homelab.local"
                ;;
            mongodb)
                CN="mongodb.homelab.local"
                ;;
            redis)
                CN="redis.homelab.local"
                ;;
            minio)
                CN="s3.homelab.local"
                ;;
        esac

        # Create config for SAN (Subject Alternative Names)
        cat > san.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
CN = ${CN}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${CN}
DNS.2 = localhost
DNS.3 = ${service}
IP.1 = 127.0.0.1
IP.2 = 10.10.10.111
EOF

        # Generate server key and CSR
        openssl req -newkey rsa:2048 -nodes \
          -keyout server.key -out server.csr \
          -config san.cnf

        # Sign with CA
        openssl x509 -req -in server.csr -days 365 \
          -CA ca.crt -CAkey ca.key -CAcreateserial \
          -out server.crt \
          -extensions v3_req -extfile san.cnf

        # Set permissions
        chmod 600 server.key
        chmod 644 server.crt

        # MongoDB needs combined PEM file
        if [ "$service" == "mongodb" ]; then
            cat server.key server.crt > server.pem
            chmod 600 server.pem
            echo "  ✓ Created server.pem for MongoDB"
        fi

        # Cleanup
        rm -f server.csr san.cnf

        echo "  ✓ Created server certificate"
    else
        echo "  Server certificate already exists (skipping)"
    fi

    # Verify certificate
    echo "  Verifying certificate..."
    if openssl verify -CAfile ca.crt server.crt > /dev/null 2>&1; then
        echo "  ✓ Certificate verification passed"
    else
        echo "  ✗ Certificate verification failed"
        exit 1
    fi

    cd ../..
    echo
done

echo "=== Certificate Summary ==="
echo
for service in "${SERVICES[@]}"; do
    echo "$service:"
    echo "  CA:     $service/certs/ca.crt"
    echo "  Cert:   $service/certs/server.crt"
    echo "  Key:    $service/certs/server.key"
    if [ "$service" == "mongodb" ]; then
        echo "  PEM:    $service/certs/server.pem"
    fi
done

echo
echo "✓ All certificates generated successfully!"
echo
echo "Next steps:"
echo "  1. Review certificates: openssl x509 -in certs/postgres/server.crt -text -noout"
echo "  2. Setup 1Password secrets: ./setup-1password-secrets.sh"
echo "  3. Deploy services: op inject -i docker-compose.yml | docker compose -f - up -d"
