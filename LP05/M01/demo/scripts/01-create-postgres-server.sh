#!/usr/bin/env bash
# Slide 6-7: Burstable tier for dev/test, firewall rule for client access,
# Entra-based auth alongside PostgreSQL native auth.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

echo "== Burstable B1ms tier - good fit for dev/test/demo workloads =="
if az postgres flexible-server show --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" --output none 2>/dev/null; then
  echo "PostgreSQL server '$PG_SERVER' already exists."
  if [ -f "$PG_PASSWORD_FILE" ]; then
    PG_ADMIN_PASSWORD=$(cat "$PG_PASSWORD_FILE")
  else
    echo "WARNING: server exists but no cached password file was found at $PG_PASSWORD_FILE" >&2
    echo "Azure cannot retrieve an existing server's password, only reset it. Resetting now" >&2
    echo "so this script can still print a working password (this will invalidate the old one):" >&2
    PG_ADMIN_PASSWORD=$(openssl rand -base64 18)
    az postgres flexible-server update --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" \
      --admin-password "$PG_ADMIN_PASSWORD" --output none
    echo "$PG_ADMIN_PASSWORD" > "$PG_PASSWORD_FILE"
  fi
else
  PG_ADMIN_PASSWORD=$(openssl rand -base64 18)
  # Cache the password BEFORE attempting creation, not after - if the
  # create command fails for any reason (including a purely cosmetic
  # failure like az's own table-output renderer not supporting this
  # response shape, confirmed to happen in practice under set -e), the
  # password must not be lost even though the server itself may already
  # have been created successfully.
  echo "$PG_ADMIN_PASSWORD" > "$PG_PASSWORD_FILE"
  time_step "PostgreSQL flexible server create" \
    az postgres flexible-server create \
    --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" \
    --location "$LOCATION" \
    --tier Burstable --sku-name Standard_B1ms \
    --storage-size 32 --version 16 \
    --admin-user "$PG_ADMIN_USER" --admin-password "$PG_ADMIN_PASSWORD" \
    --public-access 0.0.0.0-255.255.255.255 \
    --output none
fi

if az postgres flexible-server db show --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --database-name "$DB_NAME" --output none 2>/dev/null; then
  echo "Database '$DB_NAME' already exists."
else
  az postgres flexible-server db create \
    --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" --database-name "$DB_NAME" \
    --output none
fi

echo "== Enable Microsoft Entra authentication alongside native auth (Slide 7) =="
az postgres flexible-server microsoft-entra-admin create \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --display-name "$(az ad signed-in-user show --query displayName -o tsv)" \
  --object-id "$(az ad signed-in-user show --query id -o tsv)" \
  --type User 2>/dev/null || echo "  (skip if already set, or if not run as a user principal / insufficient Graph permissions)"

echo
echo "== Connection details for the Python script =="
echo "export PGHOST=\"${PG_SERVER}.postgres.database.azure.com\""
echo "export PGDATABASE=\"${DB_NAME}\""
echo "export PGUSER=\"${PG_ADMIN_USER}\""
echo "export PGPASSWORD=\"${PG_ADMIN_PASSWORD}\""
echo "export PGSSLMODE=\"require\""
echo "(paste the five lines above into your shell before running schema_and_queries.py)"
