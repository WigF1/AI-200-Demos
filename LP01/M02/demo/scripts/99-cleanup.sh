#!/usr/bin/env bash
# Tears down what THIS module created: the sidecar, the staging slot, the
# web app, the App Service plan, and the Key Vault.
#
# What this deliberately does NOT remove: the resource group and the ACR
# from LP01/M01 (M01's cleanup script, and this LP's, don't assume which
# order you'll tear down in). If you want to remove everything LP01
# created (both modules), run LP01/99-cleanup-all.sh instead, which
# deletes the whole resource group in one step.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Removing the sidecar (if present) and reverting to single-container mode =="
az webapp sitecontainers delete --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
  --container-name log-forwarder 2>/dev/null || echo "  (no sidecar found)"
az webapp sitecontainers convert --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
  --mode docker 2>/dev/null || true

echo "== Deleting the staging slot =="
az webapp deployment slot delete --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --slot "$STAGING_SLOT_NAME" 2>/dev/null || echo "  (no staging slot found)"

echo "== Deleting the web app =="
az webapp delete --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" 2>/dev/null \
  || echo "  (no web app found)"

echo "== Deleting the App Service plan =="
az appservice plan delete --resource-group "$RESOURCE_GROUP" --name "$APP_SERVICE_PLAN" --yes 2>/dev/null \
  || echo "  (no App Service plan found)"

echo "== Deleting the Key Vault (soft-deleted by default; purging so the name is free to reuse) =="
az keyvault delete --resource-group "$RESOURCE_GROUP" --name "$KEYVAULT_NAME" 2>/dev/null \
  || echo "  (no Key Vault found)"
az keyvault purge --name "$KEYVAULT_NAME" --location "$LOCATION" 2>/dev/null \
  || echo "  (nothing to purge)"

echo
echo "Done. Left in place: resource group '$RESOURCE_GROUP' and ACR '$ACR_NAME' (owned by LP01/M01)."
echo "To remove everything for LP01, run: ../../../99-cleanup-all.sh"
