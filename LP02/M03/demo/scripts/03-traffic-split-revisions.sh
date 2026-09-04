#!/usr/bin/env bash
# Slide 34: multiple revision mode + weighted traffic split (canary/blue-green).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

az containerapp revision set-mode --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --mode multiple

echo "== Current revisions =="
REVISION_COUNT=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "length(@)" --output tsv)
if [ "$REVISION_COUNT" -lt 2 ]; then
  echo "Only $REVISION_COUNT revision(s) exist - creating a second one (revision-scope"
  echo "env var change) so there's something to split traffic between."
  az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --set-env-vars "IMAGE_VERSION=v2-canary" --output none
fi
az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active}" --output table

LATEST=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" --output tsv)
PREVIOUS=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[1].name" --output tsv)

echo "== 20/80 canary split: $LATEST gets 20%, $PREVIOUS gets 80% =="
az containerapp ingress traffic set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --revision-weight "${LATEST}=20" "${PREVIOUS}=80" \
  --output table

echo
echo "== Proving the split actually happens: 30 requests, tallied by imageVersion =="
# The /config endpoint on the demo app reports IMAGE_VERSION from its own
# environment - the new revision above set it to "v2-canary", so which
# value comes back tells us which revision actually answered.
FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
CANARY_HITS=0
OTHER_HITS=0
for i in $(seq 1 30); do
  VERSION=$(curl -s --max-time 10 "https://${FQDN}/config" | python3 -c "import json,sys; print(json.load(sys.stdin).get('imageVersion','?'))" 2>/dev/null || echo "?")
  if [ "$VERSION" = "v2-canary" ]; then
    CANARY_HITS=$((CANARY_HITS + 1))
  else
    OTHER_HITS=$((OTHER_HITS + 1))
  fi
done
echo "canary (v2-canary): $CANARY_HITS/30 requests (~$((CANARY_HITS * 100 / 30))%, configured 20%)"
echo "other:               $OTHER_HITS/30 requests (~$((OTHER_HITS * 100 / 30))%, configured 80%)"
echo "(small sample - expect noise around the configured weights, not an exact match)"
