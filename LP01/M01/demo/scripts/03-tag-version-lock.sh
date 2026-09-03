#!/usr/bin/env bash
# Slide 6 & 8: tag vs. digest addressing, image locking.
# Answers Module 1 knowledge check Q2 (pin exact version via digest).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
DIGEST=$(az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --query digest --output tsv)
echo "By tag:    ${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "By digest: ${LOGIN_SERVER}/${IMAGE_NAME}@${DIGEST}"

az acr repository update --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --write-enabled false
az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --query "{name:name, changeableAttributes:changeableAttributes}" --output json
