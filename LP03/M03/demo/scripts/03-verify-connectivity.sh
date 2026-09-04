#!/usr/bin/env bash
# Slide 28: EndpointSlices, port-forward before external exposure.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing 2>/dev/null || true

echo "== Inspect EndpointSlices backing the Service =="
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name=inference-api-external

echo "== Port-forward to test internally before trusting the external IP =="
kubectl port-forward svc/inference-api-internal -n "$NAMESPACE" 8080:80 &
PF_PID=$!
# Always kill the port-forward on exit, even if curl below fails - without
# this, a failed curl under set -e would abort the script and leave the
# port-forward process orphaned in the background.
# Chained with print_elapsed (not a second trap - bash only keeps the
# last one set, which would otherwise silently drop the elapsed-time
# print from 00-vars.sh's trap).
trap 'kill "$PF_PID" 2>/dev/null || true; print_elapsed' EXIT
sleep 3
curl -sf --max-time 10 http://localhost:8080/health && echo || echo "  (port-forward may not have been ready yet)" >&2

echo "== Compare with the external LoadBalancer address =="
kubectl get svc inference-api-external -n "$NAMESPACE"
