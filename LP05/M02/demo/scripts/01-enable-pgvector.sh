#!/usr/bin/env bash
# Slide 17: pgvector must be allowlisted at the server level before
# CREATE EXTENSION works.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

echo "== Allowlisting the vector extension (appending, not overwriting, any existing allowlist) =="
CURRENT_EXTENSIONS=$(az postgres flexible-server parameter show --resource-group "$RESOURCE_GROUP" \
  --server-name "$PG_SERVER" --name azure.extensions --query value --output tsv)
if echo "$CURRENT_EXTENSIONS" | tr ',' '\n' | grep -qiw "VECTOR"; then
  echo "VECTOR is already allowlisted (current value: ${CURRENT_EXTENSIONS:-<empty>})."
else
  if [ -z "$CURRENT_EXTENSIONS" ]; then
    NEW_EXTENSIONS="VECTOR"
  else
    NEW_EXTENSIONS="${CURRENT_EXTENSIONS},VECTOR"
  fi
  az postgres flexible-server parameter set \
    --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
    --name azure.extensions --value "$NEW_EXTENSIONS" \
    --output none
fi

echo "Now connect (e.g. psql or the Python script) and run: CREATE EXTENSION IF NOT EXISTS vector;"
