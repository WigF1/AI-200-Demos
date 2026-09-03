#!/usr/bin/env bash
# Tears down what THIS module created: the scheduled purge task, the
# scratch/seed images from 04-seed-untagged-images.sh, and unlocks the
# v1 tag so it can be deleted later if needed.
#
# What this deliberately does NOT remove: the ACR itself, or the v1
# image. LP01/M02 depends on both to deploy to App Service. If you want
# to remove everything LP01 created (both modules), run
# LP01/99-cleanup-all.sh instead, which deletes the whole resource group.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the scheduled cleanup-untagged ACR task =="
az acr task delete --registry "$ACR_NAME" --name cleanup-untagged --yes 2>/dev/null \
  || echo "  (no cleanup-untagged task found - already removed or never created)"

echo "== Removing the scratch tag used to seed untagged manifests =="
az acr repository untag --name "$ACR_NAME" --image "${IMAGE_NAME}:scratch" 2>/dev/null \
  || echo "  (no scratch tag found - already removed or never created)"

echo "== Purging any remaining untagged manifests (leaves 'latest' and any other real tags alone) =="
az acr run --registry "$ACR_NAME" --cmd "acr purge --filter '${IMAGE_NAME}:^\$' --untagged --ago 0d" \
  /dev/null --output none 2>/dev/null || true

echo "== Unlocking v1 so it can be removed by a later full teardown =="
az acr repository update --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --write-enabled true 2>/dev/null \
  || echo "  (v1 tag not found or already unlocked)"

echo
echo "Done. Left in place (still needed by LP01/M02): resource group '$RESOURCE_GROUP', ACR '$ACR_NAME', image '${IMAGE_NAME}:${IMAGE_TAG}'."
echo "To remove everything for LP01, run: ../../../99-cleanup-all.sh"
