#!/usr/bin/env bash
# Slide 19: logs, Kudu, live break/fix demo (WEBSITES_PORT misconfiguration).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)

az webapp log config --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --docker-container-logging filesystem --output table

echo "Health:   https://${HOSTNAME}/health"
echo "Config:   https://${HOSTNAME}/config"
echo "Kudu:     https://${WEBAPP_NAME}.scm.azurewebsites.net"
cat <<'TXT'

Break/fix demo:
  1) az webapp config appsettings set -g $RESOURCE_GROUP -n $WEBAPP_NAME --settings WEBSITES_PORT=9999
     az webapp restart -g $RESOURCE_GROUP -n $WEBAPP_NAME
  2) Start log tail in another terminal: az webapp log tail -g $RESOURCE_GROUP -n $WEBAPP_NAME
  3) Hit the site again -> observe failure
  4) Fix: az webapp config appsettings set -g $RESOURCE_GROUP -n $WEBAPP_NAME --settings WEBSITES_PORT=8000
     az webapp restart -g $RESOURCE_GROUP -n $WEBAPP_NAME
TXT

az webapp log tail --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
