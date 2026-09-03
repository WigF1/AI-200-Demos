#!/usr/bin/env bash
# Slide 18, 22: custom topic with CloudEvents v1.0 input schema.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
EVENTGRID_TOPIC="evgt-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az eventgrid topic create \
  --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --location "$LOCATION" \
  --input-schema cloudeventschemav1_0 \
  --output table

echo "== Filtered event subscription: only StringIn data.status = flagged (Slide 24) =="
az eventgrid event-subscription create \
  --name moderation-flagged-sub \
  --source-resource-id "$(az eventgrid topic show -g "$RESOURCE_GROUP" -n "$EVENTGRID_TOPIC" --query id -o tsv)" \
  --endpoint-type webhook \
  --endpoint "https://example.com/webhook-placeholder" \
  --advanced-filter data.status StringIn flagged \
  --output table || echo "(replace --endpoint with a real handler URL before running for real)"

echo "== Topic endpoint and key for the Python publisher =="
az eventgrid topic show --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query endpoint --output tsv
az eventgrid topic key list --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query key1 --output tsv
