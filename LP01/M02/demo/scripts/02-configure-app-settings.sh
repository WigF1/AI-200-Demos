#!/usr/bin/env bash
# Slide 18: app settings, Key Vault reference, deployment slot + slot setting.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

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

SECRET_URI=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$KV_SECRET_NAME" --query id --output tsv)
VERSIONLESS_URI="${SECRET_URI%/*}"
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings MODEL_API_KEY="@Microsoft.KeyVault(SecretUri=${VERSIONLESS_URI}/)"

az webapp deployment slot create --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --slot "$STAGING_SLOT_NAME"
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --slot "$STAGING_SLOT_NAME" --settings APP_ENVIRONMENT="staging" --slot-settings APP_ENVIRONMENT

az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
echo "curl https://$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)/config"
