#!/usr/bin/env bash
# Slide 6: Azure Managed Redis, Balanced tier (4:1 memory:vCPU) for standard workloads.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp06}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp06-redis}"
REDIS_NAME="redis-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az extension add --name redisenterprise --upgrade --only-show-errors

echo "== Balanced_B1: 4:1 memory-to-vCPU ratio, good default for AI workloads =="
az redisenterprise create \
  --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --sku Balanced_B1 \
  --output table

echo "== Endpoint (port 10000, TLS) and access key for the Python script =="
az redisenterprise show --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
  --query hostName --output tsv
az redisenterprise database list-keys --cluster-name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" \
  --query primaryKey --output tsv
