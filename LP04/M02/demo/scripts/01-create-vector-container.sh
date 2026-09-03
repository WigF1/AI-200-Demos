#!/usr/bin/env bash
# Slide 17: vector policy set at container creation (immutable after creation).
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp04}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp04-cosmosdb}"
COSMOS_ACCOUNT="cosmos-${SUFFIX}"
DATABASE_NAME="ragstore"
CONTAINER_NAME="doc_embeddings"

VECTOR_POLICY='{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":1536,"distanceFunction":"cosine"}]}'
INDEXING_POLICY='{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[{"path":"/embedding/*"},{"path":"/\"_etag\"/?"}],"vectorIndexes":[{"path":"/embedding","type":"diskANN"}]}'

az cosmosdb sql container create \
  --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$CONTAINER_NAME" \
  --partition-key-path "/category" \
  --idx "$INDEXING_POLICY" \
  --vector-embedding-policy "$VECTOR_POLICY" \
  --output table
