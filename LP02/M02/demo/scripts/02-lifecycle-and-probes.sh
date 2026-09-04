#!/usr/bin/env bash
# Slide 19, 21: readiness/liveness probes and lifecycle actions
# (deactivate/restart), tuned for AI-style slow startup.
#
# Actually applies probes via YAML and actually runs the lifecycle
# actions - a previous version of this script just printed the commands
# to run manually.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/app-health.sh

echo "== Export current config, add readiness + liveness probes on /health =="
# Re-submitting the FULL current export (not a hand-written minimal YAML)
# is deliberate: az containerapp update --yaml has documented cases of
# silently dropping fields that aren't present in the file you give it
# (e.g. scale rules, env vars from other tooling) - see
# https://github.com/microsoft/azure-container-apps/issues/516 and
# https://github.com/Azure/azure-cli/issues/32012. Exporting first and
# only adding the probes array to that export keeps everything else
# exactly as it was.
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output yaml > /tmp/aca-app.yaml

# This step needs PyYAML, which isn't guaranteed to be installed. Degrade
# gracefully rather than failing the whole script over an optional part
# of the demo - the lifecycle actions below are the more central part.
python3 -c "import yaml" 2>/dev/null || pip install --quiet --user pyyaml 2>/dev/null \
  || pip install --quiet --break-system-packages pyyaml 2>/dev/null || true

if python3 -c "import yaml" 2>/dev/null; then
  python3 - <<'PYEOF'
import yaml
with open("/tmp/aca-app.yaml") as f:
    doc = yaml.safe_load(f)
container = doc["properties"]["template"]["containers"][0]
container["probes"] = [
    {
        "type": "Readiness",
        "httpGet": {"path": "/health", "port": 8000},
        "initialDelaySeconds": 5,
        "periodSeconds": 5,
        "failureThreshold": 3,
    },
    {
        "type": "Liveness",
        "httpGet": {"path": "/health", "port": 8000},
        "initialDelaySeconds": 15,
        "periodSeconds": 10,
        "failureThreshold": 5,
    },
]
with open("/tmp/aca-app.yaml", "w") as f:
    yaml.safe_dump(doc, f, default_flow_style=False)
PYEOF

  az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --yaml /tmp/aca-app.yaml --output table

  echo "== Confirm the probes actually landed in the config =="
  az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --query "properties.template.containers[0].probes" --output json
else
  echo "PyYAML not available and couldn't be installed - skipping the probes config step."
  echo "To do this manually: edit /tmp/aca-app.yaml (add a probes: block under"
  echo "properties.template.containers[0]) then run:"
  echo "  az containerapp update -n $ACA_APP -g $RESOURCE_GROUP --yaml /tmp/aca-app.yaml"
fi

FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
echo "== Confirm the app is still healthy after the probe config change =="
wait_for_app_health "https://${FQDN}/health" true || true

echo
echo "== Lifecycle action: deactivate the current revision (isolates it, safest first step) =="
LATEST_REVISION=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" --output tsv)
az containerapp revision deactivate --revision "$LATEST_REVISION" --resource-group "$RESOURCE_GROUP" --output none
az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active}" --output table

echo "== Confirm the app is unreachable with its only revision deactivated =="
wait_for_app_health "https://${FQDN}/health" false 6 5 || true

echo
echo "== Lifecycle action: reactivate (broader than deactivate - clears the isolation) =="
az containerapp revision activate --revision "$LATEST_REVISION" --resource-group "$RESOURCE_GROUP" --output none
echo "== Confirm the app is reachable again =="
wait_for_app_health "https://${FQDN}/health" true || true
