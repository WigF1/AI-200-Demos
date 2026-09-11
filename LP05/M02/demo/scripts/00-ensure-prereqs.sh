#!/usr/bin/env bash
# Makes this module runnable without LP05/M01 having run first.
set -euo pipefail

echo "== Ensuring prerequisites for LP05/M02 (server, database) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az postgres flexible-server show --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" --output none 2>/dev/null; then
  echo "PostgreSQL server '$PG_SERVER' already exists."
  if [ -f "$PG_PASSWORD_FILE" ]; then
    PG_ADMIN_PASSWORD=$(cat "$PG_PASSWORD_FILE")
  else
    echo "WARNING: server exists but no cached password file was found at $PG_PASSWORD_FILE" >&2
    echo "Resetting the admin password so this script can still produce a working one:" >&2
    PG_ADMIN_PASSWORD=$(openssl rand -base64 18)
    az postgres flexible-server update --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" \
      --admin-password "$PG_ADMIN_PASSWORD" --output none
    echo "$PG_ADMIN_PASSWORD" > "$PG_PASSWORD_FILE"
  fi
else
  echo "PostgreSQL server not found - creating (LP05/M01 likely hasn't run; this takes several minutes)..."
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
  --name "$DB_NAME" --output none 2>/dev/null; then
  echo "Database '$DB_NAME' already exists."
else
  az postgres flexible-server db create \
    --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" --name "$DB_NAME" \
    --output none
fi

echo "Prerequisites ready."
