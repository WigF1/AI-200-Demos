#!/usr/bin/env bash
# Slide 18: PVC bound status, then prove data survives a Pod restart.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

kubectl apply -n "$NAMESPACE" -f ../manifests/pvc.yaml

echo "== Confirm PVC status is Bound =="
kubectl get pvc inference-api-data -n "$NAMESPACE" -w &
WATCH_PID=$!
sleep 15
kill "$WATCH_PID" 2>/dev/null || true
kubectl get pvc inference-api-data -n "$NAMESPACE"

echo "== Write a test file, delete the Pod, verify the file persists =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -n "$NAMESPACE" -- sh -c "echo 'hello from before restart' > /data/test.txt"
kubectl delete pod "$POD" -n "$NAMESPACE"
kubectl rollout status deployment/inference-api -n "$NAMESPACE"

NEW_POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $NEW_POD -- reading the same file back:"
kubectl exec "$NEW_POD" -n "$NAMESPACE" -- cat /data/test.txt
