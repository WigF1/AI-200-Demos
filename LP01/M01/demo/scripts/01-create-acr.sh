#!/usr/bin/env bash
# Slide 5: managed, private registry service; Basic/Standard/Premium tiers
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
  --sku Standard --admin-enabled false --output table
az acr show --name "$ACR_NAME" --query loginServer --output tsv
