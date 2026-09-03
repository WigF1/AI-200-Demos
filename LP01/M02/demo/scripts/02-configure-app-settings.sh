#!/usr/bin/env bash
# Slide 18: app settings, Key Vault reference, deployment slot + slot setting.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/rbac-wait.sh

# This module's own script 01 must have run first (webapp must exist) - that's
# expected in-module ordering, not the cross-module dependency this repo is
# fixing. If it's missing, fail with a clear pointer rather than a cryptic
# az error further down.
if ! az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output none 2>/dev/null; then
  echo "Web app '$WEBAPP_NAME' not found. Run ./01-deploy-app-service.sh first." >&2
  exit 1
fi

az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings APP_ENVIRONMENT="production" FEATURE_X_ENABLED="true" \
    MODEL_ENDPOINT="https://api.example.com/v1/classify" IMAGE_VERSION="$IMAGE_TAG"

az keyvault create --resource-group "$RESOURCE_GROUP" --name "$KEYVAULT_NAME" \
  --location "$LOCATION" --enable-rbac-authorization true --output table
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$KV_SECRET_NAME" \
  --value "demo-api-key-not-real-1234567890" --output none

PRINCIPAL_ID=$(az webapp identity show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --query principalId --output tsv)
KV_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query id --output tsv)
az role assignment create --assignee "$PRINCIPAL_ID" --scope "$KV_ID" --role "Key Vault Secrets User"
wait_for_role_assignment "$PRINCIPAL_ID" "$KV_ID" "Key Vault Secrets User"

SECRET_URI=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$KV_SECRET_NAME" --query id --output tsv)
VERSIONLESS_URI="${SECRET_URI%/*}"
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings MODEL_API_KEY="@Microsoft.KeyVault(SecretUri=${VERSIONLESS_URI}/)"

az webapp deployment slot create --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --slot "$STAGING_SLOT_NAME"
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --slot "$STAGING_SLOT_NAME" --settings APP_ENVIRONMENT="staging" --slot-settings APP_ENVIRONMENT

az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Verifying the Key Vault reference resolved (not stuck as an unresolved pointer) =="
for attempt in $(seq 1 8); do
  KV_STATUS=$(az webapp config appsettings list --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
    --query "[?name=='MODEL_API_KEY'].value | [0]" --output tsv)
  # A resolved reference reads back as the app setting's own key vault
  # reference status, not the secret value itself - check the dedicated API.
  RESOLVE_STATUS=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${WEBAPP_NAME}/config/configreferences/appsettings?api-version=2022-03-01" \
    --query "properties.MODEL_API_KEY.status" --output tsv 2>/dev/null || echo "Unknown")
  if [ "$RESOLVE_STATUS" = "Resolved" ]; then
    echo "MODEL_API_KEY Key Vault reference status: Resolved"
    break
  fi
  echo "  attempt ${attempt}: status=$RESOLVE_STATUS - retrying in 10s"
  sleep 10
done
if [ "$RESOLVE_STATUS" != "Resolved" ]; then
  echo "Reference did not resolve after ~80s (status: $RESOLVE_STATUS). Usually RBAC propagation - re-run this script." >&2
fi

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
echo
echo "== /config endpoint (confirms app settings landed in the running container) =="
curl -s "https://${HOSTNAME}/config" || echo "  (app may still be restarting - retry manually: curl https://${HOSTNAME}/config)"
