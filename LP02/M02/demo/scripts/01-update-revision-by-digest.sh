#!/usr/bin/env bash
# Slide 18: image identity - tags are mutable, digests are immutable.
# Rebuild the same Dockerfile (bump IMAGE_VERSION) and deploy by digest
# for production traceability.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

echo "== Rebuild image (simulates a new release) =="
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR"

DIGEST=$(az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --query digest --output tsv)
IMAGE_BY_DIGEST="${LOGIN_SERVER}/${IMAGE_NAME}@${DIGEST}"
echo "Deploying by digest: $IMAGE_BY_DIGEST"

echo "== New revision, verify health before shifting traffic =="
az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --image "$IMAGE_BY_DIGEST" --output table

az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active, healthState:properties.healthState}" \
  --output table
