#!/usr/bin/env bash
# Deletes the entire LP08 resource group - Key Vault and App Configuration,
# all in one place.
#
# The vault is deleted and PURGED first: Key Vault soft-delete keeps a
# deleted vault (and its name - names are global) for 90 days, so without
# the purge, LP08/M01's 01-create-keyvault fails on the next run with a
# name conflict. App Configuration is created on the Free tier, which has
# no soft-delete, so the resource group delete is enough for it.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp08}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp08-secrets-config}"
KEYVAULT_NAME="kv-${SUFFIX}"

echo "This will delete resource group '$RESOURCE_GROUP' and everything in it,"
echo "and permanently purge Key Vault '$KEYVAULT_NAME' (no soft-delete recovery)."
read -r -p "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

echo "== Deleting and purging Key Vault '$KEYVAULT_NAME' =="
if az keyvault show --name "$KEYVAULT_NAME" --output none 2>/dev/null; then
  az keyvault delete --name "$KEYVAULT_NAME" --output none
fi
# Also catches a vault already soft-deleted by an earlier group delete.
if az keyvault show-deleted --name "$KEYVAULT_NAME" --output none 2>/dev/null; then
  az keyvault purge --name "$KEYVAULT_NAME" --location "$LOCATION" --output none
  echo "  Purged."
else
  echo "  (no Key Vault found)"
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started (--no-wait). Track progress with: az group show --name $RESOURCE_GROUP"
