#!/usr/bin/env bash
# Slide 30: create one container per vector index type (flat, quantizedFlat,
# diskANN) with identical vector policies otherwise, so
# compare_index_types.py can seed the same data into each and measure
# real differences. Vector policies (including index type) are immutable
# after creation - this is why the comparison needs three containers,
# not one container reconfigured three times.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

# 384 dimensions, not 1536 like M02's example - "flat" caps out at 505
# dimensions (Slide 30), so all three containers need to share a
# dimension count under that limit for the comparison to be apples-to-
# apples (and for the flat container to be creatable at all). 384
# matches common smaller embedding models in practice.
VECTOR_POLICY='{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":384,"distanceFunction":"cosine"}]}'

echo "== Enable the EnableNoSQLVectorSearch account capability (needed before creating a vector-policy container) =="
CAPABILITIES=$(az cosmosdb show --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
  --query "capabilities[].name" --output tsv)
if echo "$CAPABILITIES" | grep -q "EnableNoSQLVectorSearch"; then
  echo "Capability already enabled."
else
  az cosmosdb update --resource-group "$RESOURCE_GROUP" --name "$COSMOS_ACCOUNT" \
    --capabilities EnableNoSQLVectorSearch --output none
  echo "Capability requested. This can take up to 15 minutes to propagate - the loop"
  echo "below retries container creation automatically rather than making you re-run by hand."
fi

create_container_with_index() {
  local container_name="$1" index_type="$2"
  local indexing_policy="{\"indexingMode\":\"consistent\",\"includedPaths\":[{\"path\":\"/*\"}],\"excludedPaths\":[{\"path\":\"/embedding/*\"},{\"path\":\"/_etag/?\"}],\"vectorIndexes\":[{\"path\":\"/embedding\",\"type\":\"${index_type}\"}]}"

  if az cosmosdb sql container show --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
    --database-name "$DATABASE_NAME" --name "$container_name" --output none 2>/dev/null; then
    echo "Container '$container_name' ($index_type) already exists."
    return
  fi

  echo "== Creating '$container_name' with a $index_type vector index (retrying up to ~16 minutes if the capability is still propagating) =="
  local attempts=32
  for attempt in $(seq 1 $attempts); do
    if az cosmosdb sql container create \
      --resource-group "$RESOURCE_GROUP" --account-name "$COSMOS_ACCOUNT" \
      --database-name "$DATABASE_NAME" --name "$container_name" \
      --partition-key-path "/category" \
      --idx "$indexing_policy" \
      --vector-embeddings "$VECTOR_POLICY" \
      --output table 2>/tmp/idx-container-error.log; then
      return
    fi
    if [ "$attempt" -eq "$attempts" ]; then
      echo "Still failing after ${attempts} attempts - this may not be a propagation delay. Last error:" >&2
      cat /tmp/idx-container-error.log >&2
      exit 1
    fi
    echo "  attempt ${attempt}/${attempts}: not ready yet, retrying in 30s..."
    sleep 30
  done
}

create_container_with_index "$IDX_FLAT_CONTAINER" "flat"
create_container_with_index "$IDX_QUANTIZEDFLAT_CONTAINER" "quantizedFlat"
create_container_with_index "$IDX_DISKANN_CONTAINER" "diskANN"

echo
echo "All three containers ready. Run compare_index_types.py with the same COSMOS_ENDPOINT/"
echo "COSMOS_KEY printed by 01-create-cosmos-account.sh."
