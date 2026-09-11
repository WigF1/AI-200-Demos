#!/usr/bin/env bash
# Slide 6: Azure Managed Redis, Balanced tier (4:1 memory:vCPU) for standard workloads.
#
# Current best practice per Microsoft's own docs (learn.microsoft.com/
# en-us/azure/redis/scripts/create-manage-cache, checked 2026): "Use
# Microsoft Entra ID with managed identities to authorize requests
# against your cache if possible - it provides better security and is
# easier to use than shared access key authorization." This demo uses
# access keys throughout to match the deck's own teaching content and
# keep the Python demos approachable, but for anything beyond a training
# exercise, prefer Entra ID auth (see az redisenterprise database
# access-policy-assignment create) and managed identities instead.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

az extension add --name redisenterprise --upgrade --only-show-errors

echo "== Balanced_B1: 4:1 memory-to-vCPU ratio, good default for AI workloads =="
# az redisenterprise create's own reference description warns it will
# "overwrite/recreate, with potential downtime" an existing cluster
# rather than being a safe no-op - unlike many other az create commands,
# this one is NOT safely re-runnable without an explicit existence check.
if az redisenterprise show --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Azure Managed Redis cluster '$REDIS_NAME' already exists."
else
  # --public-network-access is required as of API version 2025-07-01
  # (confirmed the hard way: omitting it fails with "'properties.
  # publicNetworkAccess' is required in API version 2025-07-01" even
  # though the CLI itself doesn't enforce it as a required argument
  # until a later breaking-change release). Enabled is correct here
  # since the Python demos connect over the public hostname, not a
  # private endpoint - for anything beyond a training exercise, Disabled
  # plus a private endpoint is the more secure choice.
  time_step "Azure Managed Redis create" \
    az redisenterprise create \
    --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --sku Balanced_B1 \
    --public-network-access Enabled \
    --output table
fi

# access-keys-auth's default is changing from Enabled to Disabled in a
# future breaking-change release - setting it explicitly here means this
# script keeps working (these demos are key-based, see the note at the
# top of this file) regardless of when that default flips.
az redisenterprise database update --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
  --access-keys-auth Enabled --output none

echo
echo "== Connection details for the Python scripts =="
HOSTNAME=$(az redisenterprise show --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --query hostName --output tsv)
KEY=$(az redisenterprise database list-keys --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --query primaryKey --output tsv)
echo "export REDIS_HOST=\"$HOSTNAME\""
echo "export REDIS_KEY=\"$KEY\""
echo "(paste the two lines above into your shell before running any of the Python demos)"
