#!/usr/bin/env bash
# Slide 6: separate vault, RBAC authorization, grant the signed-in user
# Secrets Officer (create/manage) so the demo scripts can run end to end.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp08}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp08-secrets-config}"
KEYVAULT_NAME="kv-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az keyvault create \
  --resource-group "$RESOURCE_GROUP" --name "$KEYVAULT_NAME" --location "$LOCATION" \
  --enable-rbac-authorization true \
  --output table

USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
KV_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query id --output tsv)

echo "== Grant yourself Secrets Officer so you can seed + rotate secrets for the demo =="
az role assignment create --assignee "$USER_OBJECT_ID" --scope "$KV_ID" --role "Key Vault Secrets Officer"

echo "== Seed an initial secret version (Slide 8: each set_secret creates a new version) =="
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "openai-api-key" \
  --value "demo-api-key-v1-not-real" --output table

echo "Vault URL: https://${KEYVAULT_NAME}.vault.azure.net/"
