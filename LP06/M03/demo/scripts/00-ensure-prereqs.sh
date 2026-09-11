#!/usr/bin/env bash
# Makes this module runnable without LP06/M01 having run first.
set -euo pipefail

echo "== Ensuring prerequisites for LP06/M03 (Azure Managed Redis cluster) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

az extension add --name redisenterprise --upgrade --only-show-errors

if az redisenterprise show --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Azure Managed Redis cluster '$REDIS_NAME' already exists."
else
  echo "Redis cluster not found - creating (LP06/M01 likely hasn't run; this takes several minutes)..."
  # --public-network-access is required as of API version 2025-07-01
  # (confirmed the hard way - see LP06/M01/01-create-redis-cache.sh for
  # the full explanation of the exact error this avoids).
  time_step "Azure Managed Redis create" \
    az redisenterprise create \
    --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --sku Balanced_B1 \
    --public-network-access Enabled \
    --output table
fi

# access-keys-auth's default is changing from Enabled to Disabled in a
# future breaking-change release - set explicitly since these demos are
# key-based (see LP06/M01/01-create-redis-cache.sh for the full note).
az redisenterprise database update --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
  --access-keys-auth Enabled --output none

echo "Prerequisites ready."
