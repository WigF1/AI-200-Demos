#!/usr/bin/env bash
# Makes this module runnable without LP02/M01 having run first. Mirrors
# M01's environment + ACR + container app creation, each step checking
# existence first so this is a fast no-op when M01 already ran.
set -euo pipefail

echo "== Ensuring prerequisites for LP02/M02 (env, ACR, image, container app) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az extension add --name containerapp --upgrade --only-show-errors

if ! az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
     --workspace-name "$LOG_ANALYTICS_WORKSPACE" --output none 2>/dev/null; then
  az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE" --output table
fi
LAW_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query customerId --output tsv)
LAW_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query primarySharedKey --output tsv)

if az containerapp env show --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Container Apps environment '$ACA_ENV' already exists."
else
  az containerapp env create \
    --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
    --logs-workspace-id "$LAW_ID" --logs-workspace-key "$LAW_KEY" --output table
fi

if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "ACR '$ACR_NAME' already exists."
else
  az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
    --sku Standard --admin-enabled false --output table
fi

if ! az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --output none 2>/dev/null; then
  az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${APP_DIR}/Dockerfile" "$APP_DIR"
fi

if az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Container app '$ACA_APP' already exists."
else
  echo "Container app '$ACA_APP' not found - creating (LP02/M01 likely hasn't run)..."
  LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
  az containerapp create \
    --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV" \
    --image "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
    --target-port 8000 --ingress external \
    --registry-server "$LOGIN_SERVER" --registry-identity system \
    --system-assigned \
    --secrets "model-api-key=demo-api-key-not-real-1234567890" \
    --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" \
               "MODEL_API_KEY=secretref:model-api-key" \
    --min-replicas 1 --max-replicas 3 \
    --output table

  PRINCIPAL_ID=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --query identity.principalId --output tsv)
  ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)
  source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/rbac-wait.sh"
  ensure_role_assignment "$PRINCIPAL_ID" "$ACR_ID" "AcrPull"
  az containerapp revision restart --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --revision "$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --query '[0].name' --output tsv)" \
    --output none || true
fi

echo "Prerequisites ready."
