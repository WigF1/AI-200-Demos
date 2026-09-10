#!/usr/bin/env bash
# Reverts the two tuned server parameters back to PostgreSQL's own
# defaults (random_page_cost=4, work_mem=4096 KB / 4MB). The server
# itself is left in place since M01 owns creating/deleting it.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Reverting random_page_cost and work_mem to PostgreSQL defaults =="
az postgres flexible-server parameter set --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --name random_page_cost --value "4" --output table 2>/dev/null || echo "  (no server found)"
az postgres flexible-server parameter set --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --name work_mem --value "4096" --output table 2>/dev/null || true

echo
echo "Left in place: PostgreSQL server, database, and its data."
echo "To remove everything for LP05, run: ../../99-cleanup-all.sh"
