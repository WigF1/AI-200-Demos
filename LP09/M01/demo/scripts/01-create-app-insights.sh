#!/usr/bin/env bash
# Slide 9: Log Analytics workspace + workspace-based Application Insights.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp09}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp09-observe}"
LOG_ANALYTICS_WORKSPACE="law-${SUFFIX}"
APP_INSIGHTS="appi-${SUFFIX}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
  --output table
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE" --query id --output tsv)

az monitor app-insights component create \
  --resource-group "$RESOURCE_GROUP" --app "$APP_INSIGHTS" --location "$LOCATION" \
  --workspace "$WORKSPACE_ID" \
  --output table

echo "== Connection string for the Python app (Slide 7: routes telemetry to App Insights) =="
az monitor app-insights component show \
  --resource-group "$RESOURCE_GROUP" --app "$APP_INSIGHTS" \
  --query connectionString --output tsv
