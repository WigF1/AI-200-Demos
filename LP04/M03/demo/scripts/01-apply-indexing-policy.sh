#!/usr/bin/env bash
# Slide 29, 31: selective indexing (exclude all by default) + a composite
# index matching a documentType filter + uploadDate DESC sort.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp04}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp04-cosmosdb}"
COSMOS_ACCOUNT="cosmos-${SUFFIX}"
DATABASE_NAME="ragstore"
CONTAINER_NAME="documents"

INDEXING_POLICY='{
  "indexingMode": "consistent",
  "includedPaths": [
    {"path": "/categoryId/?"},
    {"path": "/documentType/?"},
    {"path": "/uploadDate/?"}
  ],
  "excludedPaths": [
    {"path": "/*"},
    {"path": "/embedding/*"}
  ],
  "compositeIndexes": [
    [
      {"path": "/documentType", "order": "ascending"},
      {"path": "/uploadDate", "order": "descending"}
    ]
  ]
}'

az cosmosdb sql container update \
  --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$CONTAINER_NAME" \
  --idx "$INDEXING_POLICY" \
  --output table
