#!/usr/bin/env bash
# Companion to 01-http-scale-rule.sh: that script only CONFIGURES the scale
# rule - this one actually generates concurrent load and watches replica
# count increase, so the scale rule's effect is visible, not just its config.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

if ! az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
     --query "properties.template.scale.rules[?name=='http-scale-rule']" --output tsv 2>/dev/null | grep -q .; then
  echo "No 'http-scale-rule' scale rule found - run ./01-http-scale-rule.sh first." >&2
  exit 1
fi

FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)

echo "== Baseline replica count =="
az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output table

echo
echo "== Generating concurrent load for 90s (20 parallel loops hitting /classify) =="
# Plain background curl loops rather than a load-testing tool (hey/ab/wrk)
# so this doesn't need anything beyond curl, which the rest of this repo
# already depends on.
LOAD_PIDS=()
for worker in $(seq 1 20); do
  ( end=$((SECONDS + 90))
    while [ $SECONDS -lt $end ]; do
      curl -s --max-time 10 -X POST "https://${FQDN}/classify" \
        -H "Content-Type: application/json" \
        -d '{"text":"scale test payload"}' --output /dev/null || true
    done
  ) &
  LOAD_PIDS+=($!)
done

echo "== Polling replica count every 15s while load runs =="
for check in $(seq 1 6); do
  sleep 15
  COUNT=$(az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --query "length(@)" --output tsv 2>/dev/null || echo "?")
  echo "  t+${check}x15s: $COUNT replica(s)"
done

echo "== Stopping load generators =="
for pid in "${LOAD_PIDS[@]}"; do
  kill "$pid" 2>/dev/null || true
done
wait 2>/dev/null || true

echo
echo "== Final replica list =="
az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output table
echo "Replicas will scale back down on their own after the cooldown period (no traffic)."
