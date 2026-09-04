#!/usr/bin/env bash
# Slide 10: logs (fastest signal), revisions (version check), replicas (scaling check).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Console + system logs (5s sample) =="
timeout 5 az containerapp logs show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --follow || true

echo "== Revisions =="
az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active, healthState:properties.healthState, trafficWeight:properties.trafficWeight}" \
  --output table

echo "== Replicas for the current revision =="
LATEST_REVISION=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" --output tsv)
az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --revision "$LATEST_REVISION" --output table
