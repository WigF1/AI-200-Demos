#!/usr/bin/env bash
# Slide 30: HTTP concurrency scale rule; multiple rules use the highest replica count.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/aca-scale-rules.sh

# Uses the shared helper (not a plain az containerapp update) so this
# doesn't wipe out 02-keda-servicebus-scaler.sh's rule if that already
# ran - az containerapp update replaces the entire scale rule set by
# default. See shared/lib/aca-scale-rules.sh for why.
add_or_update_scale_rule "$ACA_APP" "$RESOURCE_GROUP" "http-scale-rule" \
  --min-replicas 0 --max-replicas 10 \
  --scale-rule-name http-scale-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 10

echo "== Confirming all scale rules present =="
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.scale" --output json
