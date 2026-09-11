#!/usr/bin/env bash
# Slide 30: Flex Consumption plan - per-function scaling, scales to zero.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az storage account show --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" --output none 2>/dev/null; then
  echo "Storage account '$STORAGE_ACCOUNT' already exists."
else
  az storage account create \
    --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" \
    --location "$LOCATION" --sku Standard_LRS --output table
fi

echo "== Flex Consumption plan - querying the currently-supported Python version rather than hardcoding one =="
# Confirmed against Microsoft's own docs that supported Flex Consumption
# runtime versions change over time and vary by region (their own
# "how-to" doc's prose lags behind what the dynamic lookup actually
# returns) - querying it directly avoids shipping a version number that
# quietly stops being supported.
PYTHON_VERSION=$(az functionapp list-flexconsumption-runtimes --location "$LOCATION" --runtime python \
  --query "[].version" --output tsv | sort -V | tail -1)
echo "Using Python ${PYTHON_VERSION} (highest version currently supported for Flex Consumption in $LOCATION)"

if az functionapp show --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" --output none 2>/dev/null; then
  echo "Function app '$FUNCTION_APP' already exists."
else
  time_step "Function App create (Flex Consumption)" \
    az functionapp create \
    --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" \
    --storage-account "$STORAGE_ACCOUNT" \
    --flexconsumption-location "$LOCATION" \
    --runtime python --runtime-version "$PYTHON_VERSION" \
    --os-type Linux \
    --output table
fi

echo "== Managed identity for identity-based Service Bus / Key Vault connections (Slide 35) =="
az functionapp identity assign --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" --output table

echo "Function app: https://${FUNCTION_APP}.azurewebsites.net"
