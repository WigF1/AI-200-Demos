#!/usr/bin/env bash
# Slide 30: HTTP concurrency scale rule; multiple rules use the highest replica count.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --min-replicas 0 --max-replicas 10 \
  --scale-rule-name http-scale-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 10 \
  --output table

az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.scale" --output json
