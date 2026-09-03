#!/usr/bin/env bash
# Slide 17: store, RBAC Data Reader for the app identity, labeled key-values,
# and a feature flag.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp08}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp08-secrets-config}"
APPCONFIG_NAME="appcs-${SUFFIX}"
KEYVAULT_NAME="kv-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az appconfig create \
  --resource-group "$RESOURCE_GROUP" --name "$APPCONFIG_NAME" --location "$LOCATION" \
  --sku Free \
  --output table

USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
APPCONFIG_ID=$(az appconfig show --resource-group "$RESOURCE_GROUP" --name "$APPCONFIG_NAME" --query id --output tsv)
az role assignment create --assignee "$USER_OBJECT_ID" --scope "$APPCONFIG_ID" --role "App Configuration Data Owner"

echo "== Labeled key-values (Slide 18: labels create environment-specific variants) =="
az appconfig kv set --name "$APPCONFIG_NAME" --key "Pipeline:BatchSize" --value "10" --label "Production" --yes
az appconfig kv set --name "$APPCONFIG_NAME" --key "Pipeline:BatchSize" --value "2" --label "Development" --yes

echo "== Feature flag (Slide 18) =="
az appconfig feature set --name "$APPCONFIG_NAME" --feature "UseNewModel" --yes

echo "== Key Vault reference (Slide 19) - requires kv-<suffix> from LP08/M01 =="
if az keyvault show --name "$KEYVAULT_NAME" &>/dev/null; then
  SECRET_ID=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name openai-api-key --query id --output tsv)
  az appconfig kv set-keyvault --name "$APPCONFIG_NAME" --key "OpenAI:ApiKey" --secret-identifier "$SECRET_ID" --yes

  APPCONFIG_IDENTITY_TBD="grant the app's managed identity 'App Configuration Data Reader' on this store"
  echo "$APPCONFIG_IDENTITY_TBD AND 'Key Vault Secrets User' on $KEYVAULT_NAME (Slide 22 knowledge check)"
else
  echo "(kv-${SUFFIX} not found - run LP08/M01's 01-create-keyvault first for the reference demo)"
fi

echo "App Configuration endpoint:"
az appconfig show --resource-group "$RESOURCE_GROUP" --name "$APPCONFIG_NAME" --query endpoint --output tsv
