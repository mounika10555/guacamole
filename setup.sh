#!/bin/bash

set -e

echo "======================================"
echo "Starting Guacamole LDAP Environment"
echo "======================================"

echo "[1/8] Starting containers..."
docker compose up -d

echo "[2/8] Waiting for LDAP..."

until docker exec ldap ldapsearch \
  -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin \
  -b "dc=example,dc=com" \
  -s base >/dev/null 2>&1
do
    echo "LDAP is not ready. Waiting..."
    sleep 3
done

echo "LDAP is ready."

echo "[3/8] Importing users and groups..."

docker cp init.ldif ldap:/tmp/init.ldif

MSYS_NO_PATHCONV=1 docker exec ldap ldapadd \
  -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin \
  -f /tmp/init.ldif || true

echo "[4/8] Installing Guacamole LDAP schema..."

echo "Checking Guacamole LDAP extension..."

docker exec guacamole sh -c \
  "find /opt/guacamole/extensions -maxdepth 4 -type f -iname 'guacConfigGroup.ldif' 2>/dev/null"

SCHEMA_PATH=$(docker exec guacamole sh -c \
  "find /opt/guacamole/extensions -iname 'guacConfigGroup.ldif' 2>/dev/null | head -1")

if [ -z "$SCHEMA_PATH" ]; then
    echo "ERROR: guacConfigGroup.ldif not found in Guacamole container."
    echo "LDAP extension/schema is not available."
    exit 1
fi

echo "Found schema at: $SCHEMA_PATH"

echo "Copying schema from Guacamole container..."

docker cp \
  "guacamole:$SCHEMA_PATH" \
  ./guacConfigGroup.ldif

if [ ! -f "./guacConfigGroup.ldif" ]; then
    echo "ERROR: Schema copy failed."
    exit 1
fi

echo "Schema copied successfully."

echo "Loading Guacamole schema into LDAP..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapadd \
  -Q \
  -Y EXTERNAL \
  -H ldapi:/// < guacConfigGroup.ldif

echo "Guacamole LDAP schema installed."


echo "[5/8] Creating Guacamole OU..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapadd \
  -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin < guacamole-base.ldif || true


echo "[6/8] Creating Guacamole connections..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapadd \
  -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin < guacamole-connections.ldif || true

echo "[6/8] Creating fix-guac-schema..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapmodify \
  -Q \
  -Y EXTERNAL \
  -H ldapi:/// < fix-guac-schema.ldif


docker compose up -d --force-recreate guacamole


echo "[7/8] Applying LDAP ACL..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapmodify \
  -Q \
  -Y EXTERNAL \
  -H ldapi:/// < ldap-read-access.ldif


echo "[6/8] Creating Guacamole connections..."

MSYS_NO_PATHCONV=1 docker exec -i ldap ldapadd \
  -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin < guacamole-connections.ldif || true


echo "[8/8] Restarting Guacamole..."

docker compose up -d --force-recreate guacamole

echo "======================================"
echo "Guacamole setup completed"
echo "======================================"
echo "Open: http://localhost:8080/guacamole/"
