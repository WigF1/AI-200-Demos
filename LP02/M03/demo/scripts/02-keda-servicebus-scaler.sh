#!/usr/bin/env bash
# Slide 31, 36: KEDA azure-servicebus scaler, scale-to-zero for queue-driven workers.
# 00-ensure-prereqs.sh creates a Basic-tier namespace + queue if one
# doesn't already exist - no dependency on another learning path.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

CONN_STRING=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SERVICEBUS_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

# az containerapp update has no --secrets parameter at all (confirmed
# against the official az containerapp reference docs) - only create and
# the dedicated `secret set` command manage secrets. Using --secrets on
# update fails with "unrecognized arguments" even though it's spelled
# correctly, because argparse doesn't know that flag for this subcommand.
az containerapp secret set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --secrets "servicebus-connection=${CONN_STRING}" \
  --output none

# Confirmed against Microsoft's own tutorial: "When you use the Azure CLI
# to add a scale rule to a container app that already has a scale rule,
# the new scale rule replaces the old scale rule." A plain
# `az containerapp update --scale-rule-name ...` here would silently
# delete 01-http-scale-rule.sh's rule instead of adding alongside it -
# defeating the deck's own "multiple rules use the highest replica count"
# point, and meaning 01/02/04/05 could never all work without re-running
# each other.
#
# Rather than hand-write the azure-servicebus rule's YAML schema from
# memory (a mistake made twice already with other Container Apps/sidecar
# schemas this session), this lets the CLI itself generate the correct
# rule shape - via the same replacing update - then splices that
# CLI-generated rule into whatever rules already existed, and reapplies
# the merged result. Needs PyYAML; degrades to the old replacing
# behavior (with a clear warning) if it's not available.
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output yaml > /tmp/aca-before.yaml

python3 -c "import yaml" 2>/dev/null || pip install --quiet --user pyyaml 2>/dev/null \
  || pip install --quiet --break-system-packages pyyaml 2>/dev/null || true

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "PyYAML not available - falling back to a plain update, which WILL remove any" >&2
  echo "other scale rule already on this app (e.g. http-scale-rule from 01)." >&2
  az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --min-replicas 0 --max-replicas 5 \
    --scale-rule-name servicebus-queue-scale \
    --scale-rule-type azure-servicebus \
    --scale-rule-metadata "queueName=${SERVICEBUS_QUEUE}" "namespace=${SERVICEBUS_NAMESPACE}" "messageCount=5" \
    --scale-rule-auth "connection=servicebus-connection" \
    --output table
  exit 0
fi

python3 - <<'PYEOF'
import yaml
with open("/tmp/aca-before.yaml") as f:
    before = yaml.safe_load(f)
scale = (before.get("properties", {}).get("template", {}) or {}).get("scale", {}) or {}
existing_rules = scale.get("rules", []) or []
# Keep everything except any prior version of this exact rule (idempotent re-run).
preserved = [r for r in existing_rules if r.get("name") != "servicebus-queue-scale"]
with open("/tmp/preserved-rules.yaml", "w") as f:
    yaml.safe_dump({"preserved": preserved, "priorMaxReplicas": scale.get("maxReplicas")}, f)
PYEOF

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --min-replicas 0 --max-replicas 5 \
  --scale-rule-name servicebus-queue-scale \
  --scale-rule-type azure-servicebus \
  --scale-rule-metadata "queueName=${SERVICEBUS_QUEUE}" "namespace=${SERVICEBUS_NAMESPACE}" "messageCount=5" \
  --scale-rule-auth "connection=servicebus-connection" \
  --output none

az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output yaml > /tmp/aca-after.yaml

python3 - <<'PYEOF'
import yaml
with open("/tmp/aca-after.yaml") as f:
    after = yaml.safe_load(f)
with open("/tmp/preserved-rules.yaml") as f:
    preserved_data = yaml.safe_load(f)

scale = after["properties"]["template"]["scale"]
new_rules = scale.get("rules", []) or []  # should contain exactly the CLI-generated servicebus-queue-scale rule
merged = preserved_data["preserved"] + new_rules
scale["rules"] = merged

prior_max = preserved_data.get("priorMaxReplicas")
if isinstance(prior_max, int) and prior_max > scale.get("maxReplicas", 0):
    scale["maxReplicas"] = prior_max  # don't shrink capacity another rule (e.g. HTTP) relies on

with open("/tmp/aca-merged.yaml", "w") as f:
    yaml.safe_dump(after, f, default_flow_style=False)
PYEOF

echo "== Reapplying merged config so both scale rules coexist =="
az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --yaml /tmp/aca-merged.yaml --output table

echo "== Confirming both rules are present =="
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.scale" --output json
