#!/usr/bin/env bash
# Slide 30, 33: memory/planner tuning for vector workloads; optional read replica.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp05}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp05-postgresql}"
PG_SERVER="pg-${SUFFIX}"
PG_REPLICA="pg-${SUFFIX}-replica"

echo "== Planner/memory tuning for vector search (Slide 30) =="
az postgres flexible-server parameter set \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --name random_page_cost --value "1.1" --output table

az postgres flexible-server parameter set \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" \
  --name work_mem --value "262144" --output table   # 256MB in KB

echo "== Optional: vertical scale up before adding replicas (Slide 33) =="
echo "  az postgres flexible-server update -g $RESOURCE_GROUP -n $PG_SERVER --tier MemoryOptimized --sku-name Standard_E2ds_v4"

echo "== Optional: create a read replica for read-heavy distribution (Slide 33) =="
echo "  az postgres flexible-server replica create -g $RESOURCE_GROUP --replica-name $PG_REPLICA --source-server $PG_SERVER"
