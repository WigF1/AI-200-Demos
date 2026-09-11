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
  time_step "Azure Managed Redis create" \
    az redisenterprise create \
    --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --sku Balanced_B1 \
    --output table
fi

echo
echo "== Connection details for the Python scripts =="
HOSTNAME=$(az redisenterprise show --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --query hostName --output tsv)
KEY=$(az redisenterprise database list-keys --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --query primaryKey --output tsv)
echo "export REDIS_HOST=\"$HOSTNAME\""
echo "export REDIS_KEY=\"$KEY\""
echo "(paste the two lines above into your shell before running any of the Python demos)"
