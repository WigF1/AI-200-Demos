#!/usr/bin/env bash
# Extends M02 with Azure Key Vault integration via the Secrets Store CSI
# Driver - Microsoft's current recommended way to get Key Vault secrets
# into AKS pods. Uses the driver's own auto-created managed identity
# (the "Access with managed identity" method), which is simpler than
# full Workload Identity (OIDC issuer + federated credentials) while
# still fully current - not the "AAD Pod Identity" project, which was
# deprecated in October 2022. See:
# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access
#
# Demonstrates the retrieved secret TWO ways, both runnable without the
# Azure Portal:
#   1. Mounted as a file at /mnt/secrets-store (the CSI driver's native
#      behavior) - proven via kubectl exec + cat.
#   2. Synced to a native Kubernetes Secret (the SecretProviderClass's
#      secretObjects field) and wired into MODEL_API_KEY, so the app's
#      own /config endpoint reports it exactly like it already does for
#      the plain K8s Secret from 01-apply-config-and-secrets.sh - this
#      supersedes that earlier source rather than running alongside it.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/rbac-wait.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing

if ! kubectl get deployment inference-api -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Deployment not found - run ./01-apply-config-and-secrets.sh first." >&2
  exit 1
fi
# A plain "deployment exists" check isn't strict enough here: the base
# M01 deployment (no run of 01-apply-config-and-secrets.sh yet) has no
# MODEL_API_KEY env var at all, so the env-patching step below would
# silently find nothing to patch instead of wiring Key Vault in.
if ! kubectl get deployment inference-api -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | grep -qw MODEL_API_KEY; then
  echo "Deployment exists but has no MODEL_API_KEY env var yet - run ./01-apply-config-and-secrets.sh first." >&2
  exit 1
fi

echo "== Enable the Azure Key Vault provider for Secrets Store CSI Driver add-on =="
ADDON_ENABLED=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
  --query "addonProfiles.azureKeyvaultSecretsProvider.enabled" --output tsv 2>/dev/null || echo "")
if [ "$ADDON_ENABLED" != "True" ] && [ "$ADDON_ENABLED" != "true" ]; then
  az aks enable-addons --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
    --addons azure-keyvault-secrets-provider --output table
else
  echo "Add-on already enabled."
fi

# Wait for the driver's own DaemonSet pods to be Ready on nodes before
# doing anything that depends on it - a Pod trying to mount a CSI volume
# before this is ready sits in ContainerCreating indefinitely rather
# than failing with a clear error, and the earlier RBAC propagation
# waits don't cover this at all (they're a completely separate thing:
# whether the identity has the right role, not whether the driver
# itself is up). Verification command per Microsoft's own docs:
# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver
echo "== Waiting for the Secrets Store CSI driver to be ready on nodes =="
kubectl wait --for=condition=Ready pod \
  -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)' \
  -n kube-system --timeout=180s \
  || echo "  driver pods did not report Ready within 180s - check: kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)' -o wide" >&2

echo "== Create the Key Vault (RBAC-mode) if it doesn't already exist =="
if az keyvault show --name "$KEYVAULT_NAME" --output none 2>/dev/null; then
  echo "Key Vault '$KEYVAULT_NAME' already exists."
else
  az keyvault create --resource-group "$RESOURCE_GROUP" --name "$KEYVAULT_NAME" \
    --location "$LOCATION" --enable-rbac-authorization true --output table
fi
KV_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query id --output tsv)
KV_TENANT_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query properties.tenantId --output tsv)

# --enable-rbac-authorization true means creating the vault grants YOU no
# data-plane rights on it (same gotcha as LP01/M02/02-configure-app-
# settings.sh) - grant yourself Key Vault Secrets Officer before writing
# the demo secret.
CALLER_ID=$(get_current_principal_id)
echo "== Granting the caller Key Vault Secrets Officer so this script can write the secret =="
ensure_role_assignment "$CALLER_ID" "$KV_ID" "Key Vault Secrets Officer"

echo "== Writing the demo secret =="
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$KV_SECRET_NAME" \
  --value "demo-api-key-from-keyvault-1234567890" --output none

echo "== Grant the add-on's own auto-created managed identity read access =="
# The add-on creates this identity automatically when enabled (named
# azurekeyvaultsecretsprovider-xxxxx, lives in the node resource group,
# already assigned to the node VMSS) - no need to create your own.
IDENTITY_OBJECT_ID=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.objectId" --output tsv)
IDENTITY_CLIENT_ID=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" --output tsv)
ensure_role_assignment "$IDENTITY_OBJECT_ID" "$KV_ID" "Key Vault Secrets User"

echo "== Create the SecretProviderClass - mounts as a file AND syncs to a K8s Secret =="
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ${SECRET_PROVIDER_CLASS}
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "${IDENTITY_CLIENT_ID}"
    keyvaultName: "${KEYVAULT_NAME}"
    cloudName: ""
    objects: |
      array:
        - |
          objectName: ${KV_SECRET_NAME}
          objectType: secret
          objectVersion: ""
    tenantId: "${KV_TENANT_ID}"
  secretObjects:
  - secretName: ${SYNCED_SECRET_NAME}
    type: Opaque
    data:
    - objectName: ${KV_SECRET_NAME}
      key: MODEL_API_KEY
EOF

echo "== Wire the Deployment to mount the CSI volume and source MODEL_API_KEY from the synced Secret =="
# Export first and only add what's needed (not a hand-written minimal
# YAML) - same reasoning as LP02/M02/02-lifecycle-and-probes.sh: avoid
# accidentally dropping the PVC volume or other config already there.
kubectl get deployment inference-api -n "$NAMESPACE" -o yaml > /tmp/inference-api-before.yaml

python3 -c "import yaml" 2>/dev/null || pip install --quiet --user pyyaml 2>/dev/null \
  || pip install --quiet --break-system-packages pyyaml 2>/dev/null || true

if python3 -c "import yaml" 2>/dev/null; then
  python3 - "$SECRET_PROVIDER_CLASS" "$SYNCED_SECRET_NAME" <<'PYEOF'
import sys, yaml
secret_provider_class, synced_secret = sys.argv[1], sys.argv[2]

with open("/tmp/inference-api-before.yaml") as f:
    doc = yaml.safe_load(f)

pod_spec = doc["spec"]["template"]["spec"]
container = pod_spec["containers"][0]

# Point MODEL_API_KEY at the Key-Vault-synced Secret instead of the
# plain one created in 01-apply-config-and-secrets.sh - this supersedes
# that earlier source rather than running alongside it.
for env_entry in container.get("env", []):
    if env_entry.get("name") == "MODEL_API_KEY":
        env_entry.pop("value", None)
        env_entry["valueFrom"] = {
            "secretKeyRef": {"name": synced_secret, "key": "MODEL_API_KEY"}
        }

volume_mounts = container.setdefault("volumeMounts", [])
if not any(vm.get("name") == "secrets-store-inline" for vm in volume_mounts):
    volume_mounts.append({
        "name": "secrets-store-inline",
        "mountPath": "/mnt/secrets-store",
        "readOnly": True,
    })

volumes = pod_spec.setdefault("volumes", [])
if not any(v.get("name") == "secrets-store-inline" for v in volumes):
    volumes.append({
        "name": "secrets-store-inline",
        "csi": {
            "driver": "secrets-store.csi.k8s.io",
            "readOnly": True,
            "volumeAttributes": {"secretProviderClass": secret_provider_class},
        },
    })

with open("/tmp/inference-api-after.yaml", "w") as f:
    yaml.safe_dump(doc, f, default_flow_style=False)
PYEOF

  kubectl apply -n "$NAMESPACE" -f /tmp/inference-api-after.yaml
else
  echo "PyYAML not available and couldn't be installed - can't safely wire the deployment." >&2
  echo "Install it and re-run, or manually add the CSI volume/mount and update MODEL_API_KEY's secretKeyRef." >&2
  exit 1
fi

echo "== Waiting for the rollout (mounting the CSI volume can take longer than a plain config change - RBAC and the driver may still be propagating) =="
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=180s \
  || echo "  rollout did not complete within 180s - check: kubectl describe pod -n $NAMESPACE -l app=inference-api" >&2

echo
echo "== Verify 1: the secret is mounted as a file =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD" ]; then
  echo "No Running Pod found to verify against - check: kubectl get pods -n $NAMESPACE" >&2
  exit 1
fi
kubectl exec "$POD" -n "$NAMESPACE" -- cat "/mnt/secrets-store/${KV_SECRET_NAME}"; echo

echo
echo "== Verify 2: the app's own /config endpoint resolved it via the synced K8s Secret =="
kubectl exec "$POD" -n "$NAMESPACE" -- python -c \
  "import urllib.request,json; print(json.load(urllib.request.urlopen('http://localhost:8000/config')))"

cat <<TXT

Suggested Portal checks:
  - Key Vault ($KEYVAULT_NAME) -> Secrets: confirm '$KV_SECRET_NAME' exists.
  - Key Vault -> Access control (IAM) -> Role assignments: confirm the
    add-on's identity (client ID $IDENTITY_CLIENT_ID) has 'Key Vault
    Secrets User'.
  - AKS cluster -> Settings -> Cluster configuration: confirm "Azure Key
    Vault provider for Secrets Store CSI Driver" shows Enabled.
TXT
