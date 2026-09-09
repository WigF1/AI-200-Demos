#!/usr/bin/env bash
# Shared helper: add or update ONE named Container Apps scale rule
# without wiping out any other scale rule already on the app.
#
# az containerapp update replaces the app's ENTIRE scale rule set by
# default - confirmed against Microsoft's own tutorial: "When you use
# the Azure CLI to add a scale rule to a container app that already has
# a scale rule, the new scale rule replaces the old scale rule." That
# means two scripts each adding a different rule (e.g. an HTTP rule and
# a Service Bus rule) will keep wiping each other out, in EITHER order,
# no matter which one runs second - a single script fixing just one
# direction isn't enough.
#
# This works around it without hand-writing any scale rule's YAML schema
# from memory: it captures whatever rules already exist, lets the CLI
# generate the new/updated rule via the same (still individually
# replacing) update call, then splices that CLI-generated rule back in
# alongside the preserved ones and reapplies the merged result.
#
# Usage: source this file, then:
#   add_or_update_scale_rule "$ACA_APP" "$RESOURCE_GROUP" "http-scale-rule" \
#     --min-replicas 0 --max-replicas 10 \
#     --scale-rule-name http-scale-rule --scale-rule-type http \
#     --scale-rule-http-concurrency 10
#
# The third argument is the rule's name (used to find and drop any prior
# version of it before merging, so re-running is idempotent) - everything
# after that is passed straight through to `az containerapp update`.

add_or_update_scale_rule() {
  local app="$1" rg="$2" rule_name="$3"
  shift 3

  az containerapp show --name "$app" --resource-group "$rg" --output yaml > /tmp/aca-before.yaml

  python3 -c "import yaml" 2>/dev/null || pip install --quiet --user pyyaml 2>/dev/null \
    || pip install --quiet --break-system-packages pyyaml 2>/dev/null || true

  if ! python3 -c "import yaml" 2>/dev/null; then
    echo "PyYAML not available - falling back to a plain update, which WILL remove any" >&2
    echo "other scale rule already on this app." >&2
    az containerapp update --name "$app" --resource-group "$rg" "$@" --output table
    return
  fi

  python3 - "$rule_name" <<'PYEOF'
import sys, yaml
rule_name = sys.argv[1]
with open("/tmp/aca-before.yaml") as f:
    before = yaml.safe_load(f)
scale = (before.get("properties", {}).get("template", {}) or {}).get("scale", {}) or {}
existing_rules = scale.get("rules", []) or []
preserved = [r for r in existing_rules if r.get("name") != rule_name]
with open("/tmp/preserved-rules.yaml", "w") as f:
    yaml.safe_dump({"preserved": preserved, "priorMaxReplicas": scale.get("maxReplicas")}, f)
PYEOF

  az containerapp update --name "$app" --resource-group "$rg" "$@" --output none

  az containerapp show --name "$app" --resource-group "$rg" --output yaml > /tmp/aca-after.yaml

  python3 - <<'PYEOF'
import yaml
with open("/tmp/aca-after.yaml") as f:
    after = yaml.safe_load(f)
with open("/tmp/preserved-rules.yaml") as f:
    preserved_data = yaml.safe_load(f)

scale = after["properties"]["template"]["scale"]
new_rules = scale.get("rules", []) or []
merged = preserved_data["preserved"] + new_rules
scale["rules"] = merged

prior_max = preserved_data.get("priorMaxReplicas")
if isinstance(prior_max, int) and prior_max > scale.get("maxReplicas", 0):
    scale["maxReplicas"] = prior_max  # don't shrink capacity another rule relies on

with open("/tmp/aca-merged.yaml", "w") as f:
    yaml.safe_dump(after, f, default_flow_style=False)
PYEOF

  echo "== Reapplying merged config so all scale rules coexist =="
  az containerapp update --name "$app" --resource-group "$rg" --yaml /tmp/aca-merged.yaml --output none

  # The two update calls above go through a genuinely-different-then-
  # corrected-back-again intermediate state (first call sets ONLY the new
  # rule with its own maxReplicas, second call restores the rest) - a
  # read right after this function returns can catch that transient
  # state before it's settled rather than the final merged result. Poll
  # until the live config actually matches what we just applied.
  local expected_rule_count
  expected_rule_count=$(python3 -c "
import yaml
with open('/tmp/aca-merged.yaml') as f:
    doc = yaml.safe_load(f)
print(len(doc['properties']['template']['scale'].get('rules', [])))
")
  for attempt in $(seq 1 6); do
    live_rule_count=$(az containerapp show --name "$app" --resource-group "$rg" \
      --query "length(properties.template.scale.rules)" --output tsv 2>/dev/null || echo "0")
    if [ "$live_rule_count" = "$expected_rule_count" ]; then
      break
    fi
    echo "  waiting for the merged config to settle (attempt ${attempt}: $live_rule_count/$expected_rule_count rules visible)..."
    sleep 5
  done

  echo "== Confirmed final scale config =="
  az containerapp show --name "$app" --resource-group "$rg" --query "properties.template.scale" --output json
}
