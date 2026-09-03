#!/usr/bin/env bash
# Slide 6-7: Burstable tier for dev/test, firewall rule for client access,
# Entra-based auth alongside PostgreSQL native auth.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp05}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp05-postgresql}"
PG_SERVER="pg-${SUFFIX}"
PG_ADMIN_USER="pgadmin"
PG_ADMIN_PASSWORD="${PG_ADMIN_PASSWORD:-$(openssl rand -base64 18)}"
DB_NAME="agentdb"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

echo "== Burstable B1ms tier - good fit for dev/test/demo workloads =="
az postgres flexible-server create \
  --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" \
  --location "$LOCATION" \
  --tier Burstable --sku-name Standard_B1ms \
  --storage-size 32 --version 16 \
  --admin-user "$PG_ADMIN_USER" --admin-password "$PG_ADMIN_PASSWORD" \
  --public-access 0.0.0.0-255.255.255.255 \
  --output table
echo "Generated admin password (save this): $PG_ADMIN_PASSWORD"

az postgres flexible-server db create \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" --database-name "$DB_NAME" \
  --output table

echo "== Enable Microsoft Entra authentication alongside native auth (Slide 7) =="
az postgres flexible-server microsoft-entra-admin create \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --display-name "$(az ad signed-in-user show --query displayName -o tsv)" \
  --object-id "$(az ad signed-in-user show --query id -o tsv)" \
  --type User || echo "(skip if not run as a user principal / insufficient Graph permissions)"

echo "== Connection string values for the Python script =="
echo "PGHOST=${PG_SERVER}.postgres.database.azure.com"
echo "PGDATABASE=${DB_NAME}"
echo "PGUSER=${PG_ADMIN_USER}"
echo "PGPASSWORD=${PG_ADMIN_PASSWORD}"
echo "PGSSLMODE=require"
