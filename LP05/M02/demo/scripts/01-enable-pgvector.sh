#!/usr/bin/env bash
# Slide 17: pgvector must be allowlisted at the server level before
# CREATE EXTENSION works.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp05}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp05-postgresql}"
PG_SERVER="pg-${SUFFIX}"

az postgres flexible-server parameter set \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --name azure.extensions --value "VECTOR" \
  --output table

echo "Now connect (e.g. psql or the Python script) and run: CREATE EXTENSION IF NOT EXISTS vector;"
