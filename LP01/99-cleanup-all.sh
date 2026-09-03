#!/usr/bin/env bash
# Deletes the entire LP01 resource group - everything M01 (ACR) and M02
# (App Service, Key Vault, sidecar) created. Use this instead of running
# each module's 99-cleanup.sh individually when you're done with the
# whole learning path.
#
# Prefer the per-module 99-cleanup.sh scripts if you only want to tear
# down one module's resources and keep working in the other.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp01}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp01-container-hosting}"

echo "This will delete resource group '$RESOURCE_GROUP' and everything in it."
read -r -p "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started (--no-wait). Track progress with: az group show --name $RESOURCE_GROUP"
