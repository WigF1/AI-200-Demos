#!/usr/bin/env bash
# Slide 17: vector policy set at container creation (immutable after creation).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

# CORRECTED: the container-create flag is --vector-embeddings, not
# --vector-embedding-policy - confirmed against the official az cosmosdb
# sql container reference (learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/container).
VECTOR_POLICY='{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":1536,"distanceFunction":"cosine"}]}'
INDEXING_POLICY='{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[{"path":"/embedding/*"},{"path":"/_etag/?"}],"vectorIndexes":[{"path":"/embedding","type":"diskANN"}]}'

echo "== Enable the EnableNoSQLVectorSearch account capability (needed before creating a vector-policy container) =="
CAPABILITIES=$(az cosmosdb show --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
  --query "capabilities[].name" --output tsv)
if echo "$CAPABILITIES" | grep -q "EnableNoSQLVectorSearch"; then
  echo "Capability already enabled."
else
  az cosmosdb update --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
    --capabilities EnableNoSQLVectorSearch --output none
  echo "Capability requested. Microsoft's own docs note this can take up to 15 minutes to"
  echo "propagate, even though the request itself is auto-approved - the loop below retries"
  echo "container creation automatically rather than making you wait and re-run by hand."
fi

if az cosmosdb sql container show --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
  --database-name "$DATABASE_NAME" --name "$VECTOR_CONTAINER_NAME" --output none 2>/dev/null; then
  echo "Container '$VECTOR_CONTAINER_NAME' already exists."
else
  echo "== Creating the vector-enabled container (retrying up to ~16 minutes if the capability is still propagating) =="
  ATTEMPTS=32
  for attempt in $(seq 1 $ATTEMPTS); do
    if az cosmosdb sql container create \
      --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
      --database-name "$DATABASE_NAME" --name "$VECTOR_CONTAINER_NAME" \
      --partition-key-path "/category" \
      --idx "$INDEXING_POLICY" \
      --vector-embeddings "$VECTOR_POLICY" \
      --output table 2>/tmp/vector-container-error.log; then
      break
    fi
    if [ "$attempt" -eq "$ATTEMPTS" ]; then
      echo "Still failing after ${ATTEMPTS} attempts - this may not be a propagation delay. Last error:" >&2
      cat /tmp/vector-container-error.log >&2
      exit 1
    fi
    echo "  attempt ${attempt}/${ATTEMPTS}: not ready yet, retrying in 30s..."
    sleep 30
  done
fi

echo
echo "Vector container ready. Run the Python demo with the same COSMOS_ENDPOINT/COSMOS_KEY"
echo "printed by 01-create-cosmos-account.sh (or re-print them: az cosmosdb keys list ...)."
