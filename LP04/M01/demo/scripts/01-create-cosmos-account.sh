#!/usr/bin/env bash
# Slide 6: Account -> Database -> Container -> Item resource hierarchy.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp04}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp04-cosmosdb}"
COSMOS_ACCOUNT="cosmos-${SUFFIX}"
DATABASE_NAME="ragstore"
CONTAINER_NAME="documents"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

echo "== Serverless account for demo economics (swap for provisioned RU/s in production) =="
az cosmosdb create \
  --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=false \
  --capabilities EnableServerless \
  --output table

az cosmosdb sql database create \
  --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" --name "$DATABASE_NAME" \
  --output table

echo "== Container with categoryId as the partition key (Slide 6: high-cardinality field) =="
az cosmosdb sql container create \
  --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$CONTAINER_NAME" \
  --partition-key-path "/categoryId" \
  --output table

echo "== Connection details for the Python script =="
az cosmosdb show --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" --query documentEndpoint --output tsv
az cosmosdb keys list --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" --query primaryMasterKey --output tsv
echo "Export these as COSMOS_ENDPOINT and COSMOS_KEY before running crud_and_queries.py"
