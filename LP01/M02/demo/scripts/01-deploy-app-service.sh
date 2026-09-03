#!/usr/bin/env bash
# Slide 15-17: custom Linux container from ACR, managed identity + AcrPull,
# WEBSITES_PORT, health check.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/rbac-wait.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
IMAGE_REF="${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

az appservice plan create --resource-group "$RESOURCE_GROUP" --name "$APP_SERVICE_PLAN" \
  --is-linux --sku "$WEBAPP_SKU" --output table

# You'll see a warning here: "No credential was provided to access Azure
# Container Registry... Retrieving credentials failed..." That's expected,
# not a failure - 01-create-acr.sh deliberately set --admin-enabled false,
# so there ARE no admin credentials for az to fall back to. The app is
# created pointing at the image regardless; it just can't pull it yet.
# The role assignment + acrUseManagedIdentityCreds below are what actually
# let it pull, which is the whole point of this module (managed identity
# over admin credentials, slide 16).
az webapp create --resource-group "$RESOURCE_GROUP" --plan "$APP_SERVICE_PLAN" \
  --name "$WEBAPP_NAME" --container-image-name "$IMAGE_REF" --output table

az webapp identity assign --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output table
PRINCIPAL_ID=$(az webapp identity show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --query principalId --output tsv)
ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)

az role assignment create --assignee "$PRINCIPAL_ID" --scope "$ACR_ID" --role "AcrPull"
wait_for_role_assignment "$PRINCIPAL_ID" "$ACR_ID" "AcrPull"

az webapp config set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --generic-configurations '{"acrUseManagedIdentityCreds": true}'

az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=8000

az webapp config set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --always-on true
az webapp config set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --generic-configurations '{"healthCheckPath": "/health"}'

az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
HEALTH_URL="https://${HOSTNAME}/health"
echo "== Verifying the app comes up healthy: $HEALTH_URL =="
for attempt in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "Healthy (HTTP $STATUS) after ${attempt} attempt(s)."
    break
  fi
  echo "  attempt ${attempt}: HTTP $STATUS - retrying in 10s (cold start / image pull can take a minute)"
  sleep 10
done
if [ "$STATUS" != "200" ]; then
  echo "Still not healthy after 2 minutes - check logs: az webapp log tail -g $RESOURCE_GROUP -n $WEBAPP_NAME" >&2
fi
