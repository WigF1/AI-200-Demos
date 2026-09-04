#!/usr/bin/env bash
# Slides 16-17: apply ConfigMap + Secret, verify they reach the Pod as env vars.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing
LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

kubectl apply -n "$NAMESPACE" -f ../manifests/configmap.yaml

echo "== Create the Secret imperatively so no real value is ever committed to git =="
kubectl create secret generic inference-api-secret \
  --from-literal=MODEL_API_KEY='demo-api-key-not-real-1234567890' \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# deployment-configured.yaml mounts a PVC (inference-api-data) - apply it
# here too, even though 02-attach-persistent-storage.sh is the module that
# properly covers PVCs, so the deployment below doesn't reference a volume
# that doesn't exist yet and leave its pods stuck Pending. Applying it
# twice (once here, once in 02) is harmless - kubectl apply is idempotent.
kubectl apply -n "$NAMESPACE" -f ../manifests/pvc.yaml

sed "s#<ACR_LOGIN_SERVER>#${LOGIN_SERVER}#g" ../manifests/deployment-configured.yaml > /tmp/deployment-configured.yaml
kubectl apply -n "$NAMESPACE" -f /tmp/deployment-configured.yaml
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2

echo "== Verify: the app's /config endpoint should now show modelApiKeyResolved=true =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -n "$NAMESPACE" -- python -c \
  "import urllib.request,json; print(json.load(urllib.request.urlopen('http://localhost:8000/config')))"
