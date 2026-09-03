#!/usr/bin/env bash
# Slide 34: multiple revision mode + weighted traffic split (canary/blue-green).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az containerapp revision set-mode --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --mode multiple

echo "== Current revisions =="
az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active}" --output table

LATEST=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" --output tsv)
PREVIOUS=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[1].name" --output tsv)

echo "== 20/80 canary split: $LATEST gets 20%, $PREVIOUS gets 80% =="
az containerapp ingress traffic set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --revision-weight "${LATEST}=20" "${PREVIOUS}=80" \
  --output table
