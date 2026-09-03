#!/usr/bin/env bash
# Slide 23-24: log search alert rule + action group.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp09}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp09-observe}"
APP_INSIGHTS="appi-${SUFFIX}"
ACTION_GROUP="ag-${SUFFIX}"
ALERT_NAME="high-failure-rate-${SUFFIX}"

APP_INSIGHTS_ID=$(az monitor app-insights component show \
  --resource-group "$RESOURCE_GROUP" --app "$APP_INSIGHTS" --query id --output tsv)

echo "== Action group (email placeholder - edit before real use) =="
az monitor action-group create \
  --resource-group "$RESOURCE_GROUP" --name "$ACTION_GROUP" --short-name "ai200demo" \
  --action email demo-oncall your-email@example.com \
  --output table

echo "== Log search alert: same query as Slide 23 =="
ACTION_GROUP_ID=$(az monitor action-group show -g "$RESOURCE_GROUP" -n "$ACTION_GROUP" --query id -o tsv)
QUERY="requests | where success == false | summarize failedCount = count() by cloud_RoleName | where failedCount > 10"

az monitor scheduled-query create \
  --resource-group "$RESOURCE_GROUP" --name "$ALERT_NAME" \
  --scopes "$APP_INSIGHTS_ID" \
  --condition "count \"$QUERY\" > 0" \
  --action-groups "$ACTION_GROUP_ID" \
  --evaluation-frequency 5m --window-size 15m --severity 2 \
  --output table
