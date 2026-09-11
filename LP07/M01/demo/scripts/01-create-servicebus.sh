#!/usr/bin/env bash
# Slide 5, 7: Standard tier namespace, one queue (point-to-point) and one
# topic + two subscriptions (fan-out).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" --output none 2>/dev/null; then
  echo "Service Bus namespace '$SB_NAMESPACE' already exists."
else
  time_step "Service Bus namespace create" \
    az servicebus namespace create \
    --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" \
    --sku Standard --location "$LOCATION" --output table
fi

echo "== Queue: point-to-point, competing consumers (Slide 7) =="
if az servicebus queue show --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$QUEUE_NAME" --output none 2>/dev/null; then
  echo "Queue '$QUEUE_NAME' already exists."
else
  az servicebus queue create \
    --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$QUEUE_NAME" \
    --max-delivery-count 5 --enable-dead-lettering-on-message-expiration true \
    --output table
fi

echo "== Topic + 2 subscriptions: fan-out (Slide 7, knowledge check Q1) =="
if az servicebus topic show --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$TOPIC_NAME" --output none 2>/dev/null; then
  echo "Topic '$TOPIC_NAME' already exists."
else
  az servicebus topic create \
    --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$TOPIC_NAME" \
    --output table
fi
for sub in notifications audit; do
  if az servicebus topic subscription show --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
    --topic-name "$TOPIC_NAME" --name "$sub" --output none 2>/dev/null; then
    echo "Subscription '$sub' already exists."
  else
    az servicebus topic subscription create \
      --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --topic-name "$TOPIC_NAME" \
      --name "$sub" --output table
  fi
done

echo
echo "== Connection string for the Python scripts =="
CONN_STR=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
echo "export SERVICEBUS_CONNECTION_STRING=\"$CONN_STR\""
echo "(paste the line above into your shell before running any of the Python demos)"
