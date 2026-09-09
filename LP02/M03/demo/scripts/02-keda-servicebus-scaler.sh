#!/usr/bin/env bash
# Slide 31, 36: KEDA azure-servicebus scaler, scale-to-zero for queue-driven workers.
# 00-ensure-prereqs.sh creates a Basic-tier namespace + queue if one
# doesn't already exist - no dependency on another learning path.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/aca-scale-rules.sh

CONN_STRING=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SERVICEBUS_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

# az containerapp update has no --secrets parameter at all (confirmed
# against the official az containerapp reference docs) - only create and
# the dedicated `secret set` command manage secrets. Using --secrets on
# update fails with "unrecognized arguments" even though it's spelled
# correctly, because argparse doesn't know that flag for this subcommand.
# Matches 01-http-scale-rule's max-replicas (10) on purpose - the shared
# helper no longer silently picks "whichever is higher" (see
# shared/lib/aca-scale-rules.sh for why), so if this used a different
# value, whichever script ran last would set the app's actual ceiling.
# 10 comfortably covers this demo too (20 messages / 5 per replica = ~4
# replicas needed), so there's no reason for the two scripts to disagree.
az containerapp secret set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --secrets "servicebus-connection=${CONN_STRING}" \
  --output none

# Uses the shared helper (not a plain az containerapp update) so this
# doesn't wipe out 01-http-scale-rule.sh's rule if that already ran -
# az containerapp update replaces the entire scale rule set by default.
# See shared/lib/aca-scale-rules.sh for why.
add_or_update_scale_rule "$ACA_APP" "$RESOURCE_GROUP" "servicebus-queue-scale" \
  --min-replicas 0 --max-replicas 10 \
  --scale-rule-name servicebus-queue-scale \
  --scale-rule-type azure-servicebus \
  --scale-rule-metadata "queueName=${SERVICEBUS_QUEUE}" "namespace=${SERVICEBUS_NAMESPACE}" "messageCount=5" \
  --scale-rule-auth "connection=servicebus-connection"
