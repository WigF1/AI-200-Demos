#!/usr/bin/env bash
# Tears down what THIS module created: the Function App and its storage
# account.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the Function App =="
az functionapp delete --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" 2>/dev/null \
  || echo "  (no Function App found)"

echo "== Deleting the storage account =="
az storage account delete --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" --yes 2>/dev/null \
  || echo "  (no storage account found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
