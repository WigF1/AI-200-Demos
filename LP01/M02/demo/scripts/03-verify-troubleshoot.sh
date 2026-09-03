#!/usr/bin/env bash
# Slide 19: logs and Kudu diagnostic surfaces.
# The break/fix demo (WEBSITES_PORT misconfiguration) is its own script,
# 04-break-fix-demo.sh, so it can be re-run independently and actually
# executes the steps instead of just printing them.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

if ! az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output none 2>/dev/null; then
  echo "Web app '$WEBAPP_NAME' not found. Run ./01-deploy-app-service.sh first." >&2
  exit 1
fi

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)

az webapp log config --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --docker-container-logging filesystem --output table

echo "Health:   https://${HOSTNAME}/health"
echo "Config:   https://${HOSTNAME}/config"
echo "Kudu:     https://${WEBAPP_NAME}.scm.azurewebsites.net"
echo
echo "For a live break/fix walkthrough (bad WEBSITES_PORT -> observe failure -> fix), run ./04-break-fix-demo.sh"
echo "Tailing logs now (Ctrl+C to stop) ..."

az webapp log tail --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
