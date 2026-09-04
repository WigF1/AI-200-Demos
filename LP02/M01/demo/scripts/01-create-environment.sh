#!/usr/bin/env bash
# Slide 6: Container Apps environment - shared networking + logging boundary.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az extension add --name containerapp --upgrade --only-show-errors

if az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
     --workspace-name "$LOG_ANALYTICS_WORKSPACE" --output none 2>/dev/null; then
  echo "Log Analytics workspace '$LOG_ANALYTICS_WORKSPACE' already exists."
else
  az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --output table
fi

LAW_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query customerId --output tsv)
LAW_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query primarySharedKey --output tsv)

ENV_STATE=$(az containerapp env show --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" \
  --query properties.provisioningState --output tsv 2>/dev/null || echo "")
if [ "$ENV_STATE" = "Succeeded" ]; then
  echo "Container Apps environment '$ACA_ENV' already exists and is healthy."
else
  if [ -n "$ENV_STATE" ]; then
    # Exists but not healthy (e.g. Failed) - a plain existence check would
    # otherwise treat this as "already there" and skip it forever. Azure's
    # own managed-cluster provisioning behind this resource can fail
    # (unrelated to anything in this script - a known, sometimes transient
    # Azure-side failure mode: "Error when initializing components on
    # ManagedCluster" / "managed cluster provision failed"), leaving a
    # broken environment that needs deleting before it can be retried.
    echo "Container Apps environment '$ACA_ENV' exists but is in state '$ENV_STATE' (not Succeeded) - deleting so it can be recreated cleanly."
    az containerapp env delete --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --yes
  fi
  echo "== Creating Container Apps environment (can take several minutes; if this fails with a"
  echo "   ManagedCluster/provisioning error, it's an Azure-side issue - re-running this script"
  echo "   will clean up the failed attempt and retry) =="
  time_step "Container Apps environment create" \
    az containerapp env create \
    --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --logs-workspace-id "$LAW_ID" --logs-workspace-key "$LAW_KEY" \
    --output table
fi

if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "ACR '$ACR_NAME' already exists."
else
  az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
    --sku Standard --admin-enabled false --output table
fi

if az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --output none 2>/dev/null; then
  echo "Image '${IMAGE_NAME}:${IMAGE_TAG}' already in '$ACR_NAME'."
else
  time_step "ACR build" \
    az acr build --registry "$ACR_NAME" \
    --image "${IMAGE_NAME}:${IMAGE_TAG}" --file "${APP_DIR}/Dockerfile" "$APP_DIR"
fi
