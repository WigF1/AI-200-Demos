#!/usr/bin/env bash
# Tears down what THIS module created: the container, database, and
# Cosmos DB account. M02/M03 depend on the account/database existing
# (their own 00-ensure-prereqs.sh recreates them if missing), so running
# this also affects them - use the LP-level 99-cleanup-all.sh instead if
# you're tearing down the whole learning path anyway.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting Cosmos DB account (this also removes its databases/containers) =="
az cosmosdb delete --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" --yes 2>/dev/null \
  || echo "  (no Cosmos DB account found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
