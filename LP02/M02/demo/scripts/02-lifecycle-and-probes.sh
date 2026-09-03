#!/usr/bin/env bash
# Slide 19, 21: lifecycle actions (stop/restart/deactivate) and readiness/liveness probes.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Add readiness + liveness probes tuned for AI-style startup =="
az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --set-env-vars "PROBE_DEMO=true" \
  --output table

# Probes are typically defined via YAML; export, edit, then apply as shown:
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --output yaml > /tmp/aca-app.yaml
echo "Exported current config to /tmp/aca-app.yaml - add a probes: block under"
echo "template.containers[0] with readinessProbe/livenessProbe httpGet on /health,"
echo "then: az containerapp update -n $ACA_APP -g $RESOURCE_GROUP --yaml /tmp/aca-app.yaml"

echo "== Lifecycle actions (safest -> broadest) =="
LATEST_REVISION=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" --output tsv)
echo "Deactivate one revision (isolates a bad release):"
echo "  az containerapp revision deactivate --revision $LATEST_REVISION -g $RESOURCE_GROUP"
echo "Restart the whole app (clears transient state):"
echo "  az containerapp restart -n $ACA_APP -g $RESOURCE_GROUP"
