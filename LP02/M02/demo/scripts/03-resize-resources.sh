#!/usr/bin/env bash
# Slide 22: per-replica CPU/memory sizing (memory must be >= 2x CPU).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/app-health.sh

echo "== Before: current resources =="
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.containers[0].resources" --output json

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --cpu 0.5 --memory 1.0Gi \
  --output table

echo "== After: confirms the resize actually took effect =="
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.containers[0].resources" --output json

FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
echo "== Confirm the app is still healthy on the new resource sizing =="
wait_for_app_health "https://${FQDN}/health" true || true
