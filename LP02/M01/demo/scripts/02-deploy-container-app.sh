#!/usr/bin/env bash
# Slide 7-9: containerapp create, managed identity + AcrPull, env vars/secrets.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ../../../../shared/lib/rbac-wait.sh
source ../../../../shared/lib/app-health.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
IMAGE_REF="${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

if az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Container app '$ACA_APP' already exists - updating image/env instead of creating."
  az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --image "$IMAGE_REF" \
    --set-env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" "MODEL_API_KEY=secretref:model-api-key" \
    --output table
else
  echo "== Create the container app with a system-assigned identity and a secret =="
  # --registry-identity system needs the identity to already exist to pull
  # successfully at creation time - it doesn't yet (chicken/egg), so the
  # first pull attempt during create is expected to fail/retry. The role
  # assignment + explicit restart below is what actually gets it running.
  az containerapp create \
    --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV" \
    --image "$IMAGE_REF" \
    --target-port 8000 --ingress external \
    --registry-server "$LOGIN_SERVER" --registry-identity system \
    --system-assigned \
    --secrets "model-api-key=demo-api-key-not-real-1234567890" \
    --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" \
               "MODEL_API_KEY=secretref:model-api-key" \
    --min-replicas 1 --max-replicas 3 \
    --output table
fi

PRINCIPAL_ID=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query identity.principalId --output tsv)
ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)
ensure_role_assignment "$PRINCIPAL_ID" "$ACR_ID" "AcrPull"

echo "== Restart so the app retries the image pull now that AcrPull is granted =="
az containerapp revision restart --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --revision "$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --query '[0].name' --output tsv)" \
  --output none || true

FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
echo "== App URL: https://${FQDN} =="

echo "== Verifying the app comes up healthy =="
wait_for_app_health "https://${FQDN}/health" true || \
  echo "Still not healthy - check: az containerapp logs show -n $ACA_APP -g $RESOURCE_GROUP --follow" >&2
