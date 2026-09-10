#!/usr/bin/env bash
# Tears down what THIS module created: the vector-enabled container.
# Leaves the account/database/EnableNoSQLVectorSearch capability in place
# (capabilities aren't designed to be removed, and M01/M03 depend on the
# account/database).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the vector container =="
az cosmosdb sql container delete --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$VECTOR_CONTAINER_NAME" --yes 2>/dev/null \
  || echo "  (no vector container found)"

echo
echo "Left in place: Cosmos DB account, database, base container, EnableNoSQLVectorSearch capability."
echo "To remove everything for LP04, run: ../../99-cleanup-all.sh"
