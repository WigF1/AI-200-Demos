#!/usr/bin/env bash
# Makes this module runnable without LP04/M01 having run first.
set -euo pipefail

echo "== Ensuring prerequisites for LP04/M02 (account, database, base container) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az cosmosdb show --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" --output none 2>/dev/null; then
  echo "Cosmos DB account '$COSMOS_ACCOUNT' already exists."
else
  echo "Cosmos DB account not found - creating (LP04/M01 likely hasn't run; this takes several minutes)..."
  time_step "Cosmos DB account create" \
    az cosmosdb create \
    --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
    --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=false \
    --capabilities EnableServerless \
    --output table
fi

if az cosmosdb sql database show --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --name "$DATABASE_NAME" --output none 2>/dev/null; then
  echo "Database '$DATABASE_NAME' already exists."
else
  az cosmosdb sql database create \
    --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" --name "$DATABASE_NAME" \
    --output table
fi

echo "Prerequisites ready."
