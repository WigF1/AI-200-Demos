#!/usr/bin/env bash
# Tears down what THIS module created: the Function App and its storage
# account, plus the document-jobs queue and the app identity's role
# assignment on the LP07/M01 Service Bus namespace. Your own Data Receiver
# role from local-dev-setup is left in place.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Removing the function app identity's Service Bus role assignment =="
# Before deleting the app - afterwards the assignment is orphaned
# ("Unknown" principal) and has to be found and removed by hand.
PRINCIPAL_ID=$(az functionapp identity show --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" \
  --query principalId --output tsv 2>/dev/null || true)
SB_ID=$(az servicebus namespace show --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" \
  --query id --output tsv 2>/dev/null || true)
if [ -n "$PRINCIPAL_ID" ] && [ -n "$SB_ID" ]; then
  az role assignment delete --assignee "$PRINCIPAL_ID" --scope "$SB_ID" \
    --role "Azure Service Bus Data Receiver" 2>/dev/null || echo "  (no role assignment found)"
else
  echo "  (no function app identity or Service Bus namespace found)"
fi

echo "== Deleting the '$JOBS_QUEUE' queue =="
az servicebus queue delete --resource-group "$RESOURCE_GROUP" --namespace-name "$SB_NAMESPACE" \
  --name "$JOBS_QUEUE" 2>/dev/null || echo "  (no queue found)"

echo "== Deleting the Function App =="
az functionapp delete --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" 2>/dev/null \
  || echo "  (no Function App found)"

echo "== Deleting the storage account =="
az storage account delete --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" --yes 2>/dev/null \
  || echo "  (no storage account found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
