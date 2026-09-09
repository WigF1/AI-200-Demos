#!/usr/bin/env bash
# Slide 31, 36: KEDA azure-servicebus scaler, scale-to-zero for queue-driven workers.
# 00-ensure-prereqs.sh creates a Basic-tier namespace + queue if one
# doesn't already exist - no dependency on another learning path.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

CONN_STRING=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SERVICEBUS_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

# az containerapp update has no --secrets parameter at all (confirmed
# against the official az containerapp reference docs) - only create and
# the dedicated `secret set` command manage secrets. Using --secrets on
# update fails with "unrecognized arguments" even though it's spelled
# correctly, because argparse doesn't know that flag for this subcommand.
az containerapp secret set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --secrets "servicebus-connection=${CONN_STRING}" \
  --output none

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --min-replicas 0 --max-replicas 5 \
  --scale-rule-name servicebus-queue-scale \
  --scale-rule-type azure-servicebus \
  --scale-rule-metadata "queueName=${SERVICEBUS_QUEUE}" "namespace=${SERVICEBUS_NAMESPACE}" "messageCount=5" \
  --scale-rule-auth "connection=servicebus-connection" \
  --output table
