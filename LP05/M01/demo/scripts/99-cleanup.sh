#!/usr/bin/env bash
# Tears down what THIS module created: the database and PostgreSQL
# server. Also removes the locally cached admin password file, since it
# would be meaningless once the server is gone. M02/M03 depend on the
# server/database existing (their own 00-ensure-prereqs.sh recreates them
# if missing) - use the LP-level 99-cleanup-all.sh instead if you're
# tearing down the whole learning path anyway.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the PostgreSQL flexible server (this also removes its databases) =="
az postgres flexible-server delete --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" --yes 2>/dev/null \
  || echo "  (no PostgreSQL server found)"

rm -f "$PG_PASSWORD_FILE"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
