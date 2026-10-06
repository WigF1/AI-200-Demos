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
PRINCIPAL_ID=$(az functionapp identity assign --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" \
  --query principalId --output tsv)
echo "System-assigned identity: $PRINCIPAL_ID"

echo "== Service Bus trigger wiring: queue, RBAC, app setting (Slide 33, 35) =="
# function_app.py's trigger uses connection="ServiceBusConnection" with no
# secret - the host resolves ServiceBusConnection__fullyQualifiedNamespace
# and authenticates as the app's managed identity. That needs all three of
# these; without them the app deploys fine but the trigger never fires.
if ! az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" --output none 2>/dev/null; then
  echo "Service Bus namespace '$SB_NAMESPACE' not found - run LP07/M01/demo/scripts/01-create-servicebus.sh first." >&2
  exit 1
fi
if az servicebus queue show --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$JOBS_QUEUE" --output none 2>/dev/null; then
  echo "Queue '$JOBS_QUEUE' already exists."
else
  az servicebus queue create --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
    --name "$JOBS_QUEUE" --output none
  echo "Created queue '$JOBS_QUEUE'."
fi
SB_ID=$(az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" --query id --output tsv)
if [ -n "$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$SB_ID" --role "Azure Service Bus Data Receiver" --query "[].id" --output tsv)" ]; then
  echo "Function app identity already has Azure Service Bus Data Receiver."
else
  # --assignee-principal-type avoids a Graph lookup that can fail for a
  # just-created identity that hasn't replicated yet.
  az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
    --role "Azure Service Bus Data Receiver" --scope "$SB_ID" --output none
  echo "Granted Azure Service Bus Data Receiver to the function app identity."
fi
az functionapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" \
  --settings "ServiceBusConnection__fullyQualifiedNamespace=${SB_NAMESPACE}.servicebus.windows.net" --output none
echo "Set ServiceBusConnection__fullyQualifiedNamespace=${SB_NAMESPACE}.servicebus.windows.net"

echo "Function app: https://${FUNCTION_APP}.azurewebsites.net"
