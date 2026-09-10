#!/usr/bin/env bash
# Reverts the indexing policy back to Cosmos DB's default (index
# everything) - the container itself and its data are left in place
# since M01 owns creating/deleting it.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Reverting to the default indexing policy (index all paths) =="
az cosmosdb sql container update --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$CONTAINER_NAME" \
  --idx '{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[]}' \
  --output table 2>/dev/null || echo "  (no container found)"

echo
echo "Left in place: Cosmos DB account, database, container, and its data."
echo "To remove everything for LP04, run: ../../99-cleanup-all.sh"
