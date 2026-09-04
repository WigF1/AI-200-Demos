#!/usr/bin/env bash
# Deletes the entire LP03 resource group - the AKS cluster, ACR, and
# everything all three modules deployed into the cluster. Prefer the
# per-module 99-cleanup.sh scripts if you only want to tear down one
# module's changes.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp03}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp03-aks}"

echo "This will delete resource group '$RESOURCE_GROUP' and everything in it (including the AKS cluster)."
read -r -p "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started (--no-wait). Track progress with: az group show --name $RESOURCE_GROUP"
