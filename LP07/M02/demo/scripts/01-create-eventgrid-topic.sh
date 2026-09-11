#!/usr/bin/env bash
# Slide 18, 22: custom topic with CloudEvents v1.0 input schema.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az eventgrid topic show --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --output none 2>/dev/null; then
  echo "Event Grid topic '$EVENTGRID_TOPIC' already exists."
else
  az eventgrid topic create \
    --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --location "$LOCATION" \
    --input-schema cloudeventschemav1_0 \
    --output table
fi

echo "== Filtered event subscription: only StringIn data.status = flagged (Slide 24) =="
if az eventgrid event-subscription show --name moderation-flagged-sub \
  --source-resource-id "$(az eventgrid topic show -g "$RESOURCE_GROUP" -n "$EVENTGRID_TOPIC" --query id -o tsv)" \
  --output none 2>/dev/null; then
  echo "Event subscription 'moderation-flagged-sub' already exists."
else
  az eventgrid event-subscription create \
    --name moderation-flagged-sub \
    --source-resource-id "$(az eventgrid topic show -g "$RESOURCE_GROUP" -n "$EVENTGRID_TOPIC" --query id -o tsv)" \
    --endpoint-type webhook \
    --endpoint "https://example.com/webhook-placeholder" \
    --advanced-filter data.status StringIn flagged \
    --output table || echo "(replace --endpoint with a real handler URL before running for real)"
fi

echo
echo "== Topic endpoint and key for the Python publisher =="
ENDPOINT=$(az eventgrid topic show --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query endpoint --output tsv)
KEY=$(az eventgrid topic key list --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query key1 --output tsv)
echo "export EVENTGRID_TOPIC_ENDPOINT=\"$ENDPOINT\""
echo "export EVENTGRID_TOPIC_KEY=\"$KEY\""
echo "(paste the two lines above into your shell before running the Python demos)"
