#!/usr/bin/env bash
# Slide 28: EndpointSlices, port-forward before external exposure.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Inspect EndpointSlices backing the Service =="
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name=inference-api-external

echo "== Port-forward to test internally before trusting the external IP =="
kubectl port-forward svc/inference-api-internal -n "$NAMESPACE" 8080:80 &
PF_PID=$!
sleep 3
curl -sf http://localhost:8080/health && echo
kill "$PF_PID" 2>/dev/null || true

echo "== Compare with the external LoadBalancer address =="
kubectl get svc inference-api-external -n "$NAMESPACE"
