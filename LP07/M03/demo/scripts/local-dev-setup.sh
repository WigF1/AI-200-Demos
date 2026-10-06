#!/usr/bin/env bash
# Slide 31: local dev with Core Tools + Azurite. Prepares everything
# `func start` needs that isn't in the repo:
#   - the document-jobs queue the Service Bus trigger listens on (on the
#     LP07/M01 namespace - run M01's 01-create-servicebus first)
#   - Azure Service Bus Data Receiver for YOU on that namespace: the
#     trigger connects identity-based (ServiceBusConnection__fully
#     QualifiedNamespace), which locally means your az login identity.
#     Owner/Contributor are control-plane only and don't grant this.
#   - local.settings.json, from local.settings.json.example with the real
#     namespace filled in. It's gitignored (it holds secrets in real
#     projects), so a fresh clone doesn't have one - and `func start`
#     without one generates an encrypted stub with no AzureWebJobsStorage.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if ! az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" --output none 2>/dev/null; then
  echo "Service Bus namespace '$SB_NAMESPACE' not found - run LP07/M01/demo/scripts/01-create-servicebus.sh first." >&2
  exit 1
fi

echo "== Queue '$JOBS_QUEUE' for the Service Bus trigger (Slide 33) =="
if az servicebus queue show --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" --name "$JOBS_QUEUE" --output none 2>/dev/null; then
  echo "Queue '$JOBS_QUEUE' already exists."
else
  az servicebus queue create --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
    --name "$JOBS_QUEUE" --output none
  echo "Created queue '$JOBS_QUEUE'."
fi

echo "== Azure Service Bus Data Receiver for the signed-in user (identity-based connection) =="
SB_ID=$(az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" --query id --output tsv)
ME=$(az ad signed-in-user show --query id --output tsv)
if [ -n "$(az role assignment list --assignee "$ME" --scope "$SB_ID" --role "Azure Service Bus Data Receiver" --query "[].id" --output tsv)" ]; then
  echo "Role already assigned."
else
  az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
    --role "Azure Service Bus Data Receiver" --scope "$SB_ID" --output none
  echo "Assigned. RBAC can take a few minutes to apply - early 'Unauthorized' errors from the trigger are expected."
fi

echo "== local.settings.json =="
SETTINGS=../function-app/local.settings.json
if [ -f "$SETTINGS" ] && ! grep -q '"IsEncrypted": true' "$SETTINGS"; then
  echo "$SETTINGS already exists - left unchanged."
else
  # A missing file, or the encrypted stub `func start` generates when there
  # isn't one (it only has FUNCTIONS_WORKER_RUNTIME, so it's safe to replace).
  sed "s/sb-<suffix>/${SB_NAMESPACE}/" ../function-app/local.settings.json.example > "$SETTINGS"
  echo "Wrote $SETTINGS (namespace ${SB_NAMESPACE}.servicebus.windows.net)."
fi

echo
echo "Next: start Azurite (AzureWebJobsStorage=UseDevelopmentStorage=true) in another terminal:"
echo "  npx azurite --location ~/.azurite --silent"
echo "then: cd ../function-app && func start"
