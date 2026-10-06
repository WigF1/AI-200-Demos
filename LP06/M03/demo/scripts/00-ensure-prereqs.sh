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
  # Clusters created before RediSearch was added to the create scripts
  # don't have it, and it can't be added in place - fail fast with the
  # fix rather than letting vector_storage.py die on FT.CREATE.
  modules=$(az redisenterprise database show --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
    --query "modules[].name" --output tsv)
  if ! grep -qx "RediSearch" <<<"$modules"; then
    echo "ERROR: '$REDIS_NAME' was created without the RediSearch module (modules can only be"
    echo "added at creation time). Delete it with LP06/M01/demo/scripts/99-cleanup.sh, then re-run this script to recreate it."
    exit 1
  fi
else
  echo "Redis cluster not found - creating (LP06/M01 likely hasn't run; this takes several minutes)..."
  # --public-network-access is required as of API version 2025-07-01
  # (confirmed the hard way - see LP06/M01/01-create-redis-cache.sh for
  # the full explanation of the exact error this avoids).
  # --clustering-policy EnterpriseCluster - default is OSSCluster, which
  # requires a cluster-aware client and produces MovedError against the
  # plain redis.Redis() these demos use. See
  # LP06/M01/01-create-redis-cache.sh for the full explanation. Immutable
  # after creation.
  # --modules name=RediSearch - required by LP06/M03 (FT.CREATE etc.);
  # confirmed the hard way that without it every FT.* command fails with
  # "unknown command 'FT.CREATE'". Modules can ONLY be added at creation
  # time. RediSearch also requires --eviction-policy NoEviction (default
  # is VolatileLRU; Azure docs list NoEviction as required for RediSearch).
  # Both immutable - an existing cluster without them must be deleted
  # (LP06/M01/demo/scripts/99-cleanup) and recreated.
  time_step "Azure Managed Redis create" \
    az redisenterprise create \
    --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --sku Balanced_B1 \
    --public-network-access Enabled \
    --clustering-policy EnterpriseCluster \
    --modules name=RediSearch \
    --eviction-policy NoEviction \
    --output table
fi

# access-keys-auth's default is changing from Enabled to Disabled in a
# future breaking-change release - set explicitly since these demos are
# key-based (see LP06/M01/01-create-redis-cache.sh for the full note).
az redisenterprise database update --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
  --access-keys-auth Enabled --output none

echo "Prerequisites ready."
