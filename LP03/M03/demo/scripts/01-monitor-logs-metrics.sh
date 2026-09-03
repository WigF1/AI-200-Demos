#!/usr/bin/env bash
# Slide 26: key signals - latency/errors/restarts, kubectl logs + kubectl top.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing

echo "== Pods and restart counts =="
kubectl get pods -n "$NAMESPACE" -o wide

POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
echo "== Logs for $POD =="
kubectl logs "$POD" -n "$NAMESPACE" --tail=50

echo "== CPU/memory vs. requests/limits (needs metrics-server, enabled by default in AKS) =="
kubectl top pods -n "$NAMESPACE"
