#!/usr/bin/env bash
# Slide 30: Flex Consumption plan - per-function scaling, scales to zero.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
STORAGE_ACCOUNT="st${SUFFIX}"
FUNCTION_APP="func-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az storage account create \
  --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" \
  --location "$LOCATION" --sku Standard_LRS --output table

echo "== Flex Consumption plan, Python 3.12 =="
az functionapp create \
  --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" \
  --storage-account "$STORAGE_ACCOUNT" \
  --flexconsumption-location "$LOCATION" \
  --runtime python --runtime-version 3.12 \
  --os-type Linux \
  --output table

echo "== Managed identity for identity-based Service Bus / Key Vault connections (Slide 35) =="
az functionapp identity assign --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" --output table

echo "Function app: https://${FUNCTION_APP}.azurewebsites.net"
