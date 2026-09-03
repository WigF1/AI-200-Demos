#!/usr/bin/env bash
# Slide 5, 7: Standard tier namespace, one queue (point-to-point) and one
# topic + two subscriptions (fan-out).
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
SB_NAMESPACE="sb-${SUFFIX}"
QUEUE_NAME="inference-requests"
TOPIC_NAME="inference-results"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az servicebus namespace create \
  --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" \
  --sku Standard --location "$LOCATION" --output table

echo "== Queue: point-to-point, competing consumers (Slide 7) =="
az servicebus queue create \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$QUEUE_NAME" \
  --max-delivery-count 5 --enable-dead-lettering-on-message-expiration true \
  --output table

echo "== Topic + 2 subscriptions: fan-out (Slide 7, knowledge check Q1) =="
az servicebus topic create \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$TOPIC_NAME" \
  --output table
az servicebus topic subscription create \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --topic-name "$TOPIC_NAME" \
  --name notifications --output table
az servicebus topic subscription create \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --topic-name "$TOPIC_NAME" \
  --name audit --output table

echo "== Connection string for the Python scripts =="
az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv
