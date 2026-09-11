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
  time_step "Azure Managed Redis create" \
    az redisenterprise create \
    --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --sku Balanced_B1 \
    --output table
fi

echo "Prerequisites ready."
