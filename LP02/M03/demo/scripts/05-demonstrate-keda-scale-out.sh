#!/usr/bin/env bash
# Companion to 02-keda-servicebus-scaler.sh: that script only CONFIGURES the
# KEDA scaler - this one actually sends messages to the queue and watches
# replicas scale up from zero, so the scaler's effect is visible.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

if ! az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
     --query "properties.template.scale.rules[?name=='servicebus-queue-scale']" --output tsv 2>/dev/null | grep -q .; then
  echo "No 'servicebus-queue-scale' scale rule found - run ./02-keda-servicebus-scaler.sh first." >&2
  exit 1
fi

echo "== Baseline replica count (likely 0 - min-replicas is 0 for this scaler) =="
az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output table

echo
echo "== Sending 20 messages to '$SERVICEBUS_QUEUE' =="
python3 -c "import azure.servicebus" 2>/dev/null || pip install --quiet --user azure-servicebus 2>/dev/null \
  || pip install --quiet --break-system-packages azure-servicebus 2>/dev/null || true

CONN_STRING=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$RESOURCE_GROUP" --namespace-name "$SERVICEBUS_NAMESPACE" \
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

if python3 -c "import azure.servicebus" 2>/dev/null; then
  python3 - "$CONN_STRING" "$SERVICEBUS_QUEUE" <<'PYEOF'
import sys
from azure.servicebus import ServiceBusClient, ServiceBusMessage

conn_string, queue_name = sys.argv[1], sys.argv[2]
with ServiceBusClient.from_connection_string(conn_string) as client:
    with client.get_queue_sender(queue_name) as sender:
        messages = [ServiceBusMessage(f"scale-demo-{i}") for i in range(20)]
        sender.send_messages(messages)
print("Sent 20 messages.")
PYEOF
else
  echo "azure-servicebus SDK not available and couldn't be installed - can't send messages." >&2
  echo "Install it and re-run: pip install azure-servicebus" >&2
  exit 1
fi

echo
echo "== Polling replica count every 15s (KEDA polls the queue every ~30s by default) =="
for check in $(seq 1 8); do
  sleep 15
  COUNT=$(az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --query "length(@)" --output tsv 2>/dev/null || echo "?")
  DEPTH=$(az servicebus queue show --namespace-name "$SERVICEBUS_NAMESPACE" --resource-group "$RESOURCE_GROUP" \
    --name "$SERVICEBUS_QUEUE" --query "countDetails.activeMessageCount" --output tsv 2>/dev/null || echo "?")
  echo "  t+${check}x15s: $COUNT replica(s), $DEPTH message(s) still queued"
done

echo
echo "== Final state =="
az containerapp replica list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --output table
echo "Once the queue drains and the cooldown period passes, replicas scale back to 0."
