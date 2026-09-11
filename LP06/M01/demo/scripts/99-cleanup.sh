#!/usr/bin/env bash
# Tears down what THIS module created: the Azure Managed Redis cluster
# (and its one database, deleted along with it). M02/M03 depend on the
# cluster existing (their own 00-ensure-prereqs.sh recreates it if
# missing) - use the LP-level 99-cleanup-all.sh instead if you're tearing
# down the whole learning path anyway.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the Azure Managed Redis cluster =="
az redisenterprise delete --name "$REDIS_NAME" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no Redis cluster found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
