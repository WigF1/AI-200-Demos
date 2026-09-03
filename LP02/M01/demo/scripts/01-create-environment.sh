#!/usr/bin/env bash
# Slide 6: Container Apps environment - shared networking + logging boundary.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az extension add --name containerapp --upgrade --only-show-errors

az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
  --output table

LAW_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query customerId --output tsv)
LAW_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query primarySharedKey --output tsv)

az containerapp env create \
  --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --logs-workspace-id "$LAW_ID" --logs-workspace-key "$LAW_KEY" \
  --output table

az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
  --sku Standard --admin-enabled false --output table
az acr build --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" --file "${APP_DIR}/Dockerfile" "$APP_DIR"
