#!/usr/bin/env bash
# Deletes the entire LP05 resource group - the PostgreSQL server and
# everything in it. Prefer the per-module 99-cleanup.sh scripts if you
# only want to tear down one module's changes.
set -euo pipefail
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp05-postgresql}"

echo "This will delete resource group '$RESOURCE_GROUP' and everything in it."
read -r -p "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
rm -f "$(dirname "$0")/.pg-admin-password"
echo "Deletion started (--no-wait). Track progress with: az group show --name $RESOURCE_GROUP"
