#!/usr/bin/env bash
# Slide 31, 36: KEDA azure-servicebus scaler, scale-to-zero for queue-driven workers.
# Requires an existing Service Bus namespace + queue (see LP07/M01) or edit
# the vars below to point at one.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

CONN_STRING=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SERVICEBUS_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --min-replicas 0 --max-replicas 5 \
  --secrets "servicebus-connection=${CONN_STRING}" \
  --scale-rule-name servicebus-queue-scale \
  --scale-rule-type azure-servicebus \
  --scale-rule-metadata "queueName=${SERVICEBUS_QUEUE}" "namespace=${SERVICEBUS_NAMESPACE}" "messageCount=5" \
  --scale-rule-auth "connection=servicebus-connection" \
  --output table
