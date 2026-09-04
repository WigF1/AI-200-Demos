#!/usr/bin/env bash
# Slide 18: PVC bound status, then prove data survives a Pod restart.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

kubectl apply -n "$NAMESPACE" -f ../manifests/pvc.yaml

echo "== Confirm PVC status is Bound (waits up to 60s) =="
for attempt in $(seq 1 6); do
  PVC_STATUS=$(kubectl get pvc inference-api-data -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$PVC_STATUS" = "Bound" ]; then
    echo "PVC is Bound after ${attempt} attempt(s)."
    break
  fi
  echo "  attempt ${attempt}: status=$PVC_STATUS - retrying in 10s"
  sleep 10
done
kubectl get pvc inference-api-data -n "$NAMESPACE"

echo "== Write a test file, delete the Pod, verify the file persists =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -n "$NAMESPACE" -- sh -c "echo 'hello from before restart' > /data/test.txt"
kubectl delete pod "$POD" -n "$NAMESPACE"
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2

NEW_POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $NEW_POD -- reading the same file back:"
kubectl exec "$NEW_POD" -n "$NAMESPACE" -- cat /data/test.txt
