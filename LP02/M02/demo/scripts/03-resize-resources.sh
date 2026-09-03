#!/usr/bin/env bash
# Slide 22: per-replica CPU/memory sizing (memory must be >= 2x CPU).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --cpu 0.5 --memory 1.0Gi \
  --output table

az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.containers[0].resources" --output json
