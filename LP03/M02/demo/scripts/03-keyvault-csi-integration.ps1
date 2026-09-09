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
#      the plain K8s Secret from 01-apply-config-and-secrets.ps1 - this
#      supersedes that earlier source rather than running alongside it.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/rbac-wait.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

kubectl get deployment inference-api -n $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment not found - run ./01-apply-config-and-secrets.ps1 first."
    exit 1
}

Write-Host "== Enable the Azure Key Vault provider for Secrets Store CSI Driver add-on =="
$AddonEnabled = az aks show --resource-group $ResourceGroup --name $AksCluster `
  --query "addonProfiles.azureKeyvaultSecretsProvider.enabled" --output tsv
if ($AddonEnabled -ne "True" -and $AddonEnabled -ne "true") {
    az aks enable-addons --resource-group $ResourceGroup --name $AksCluster `
      --addons azure-keyvault-secrets-provider --output table
} else {
    Write-Host "Add-on already enabled."
}

Write-Host "== Create the Key Vault (RBAC-mode) if it doesn't already exist =="
az keyvault show --name $KeyVaultName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Key Vault '$KeyVaultName' already exists."
} else {
    az keyvault create --resource-group $ResourceGroup --name $KeyVaultName `
      --location $Location --enable-rbac-authorization true --output table
}
$KvId = az keyvault show --name $KeyVaultName --query id --output tsv
$KvTenantId = az keyvault show --name $KeyVaultName --query properties.tenantId --output tsv

# --enable-rbac-authorization true means creating the vault grants YOU no
# data-plane rights on it (same gotcha as LP01/M02/02-configure-app-
# settings.ps1) - grant yourself Key Vault Secrets Officer before writing
# the demo secret.
$CallerId = Get-CurrentPrincipalId
Write-Host "== Granting the caller Key Vault Secrets Officer so this script can write the secret =="
Set-RoleAssignment -PrincipalId $CallerId -Scope $KvId -Role "Key Vault Secrets Officer"

Write-Host "== Writing the demo secret =="
az keyvault secret set --vault-name $KeyVaultName --name $KvSecretName `
  --value "demo-api-key-from-keyvault-1234567890" --output none

Write-Host "== Grant the add-on's own auto-created managed identity read access =="
# The add-on creates this identity automatically when enabled (named
# azurekeyvaultsecretsprovider-xxxxx, lives in the node resource group,
# already assigned to the node VMSS) - no need to create your own.
$IdentityObjectId = az aks show --resource-group $ResourceGroup --name $AksCluster `
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.objectId" --output tsv
$IdentityClientId = az aks show --resource-group $ResourceGroup --name $AksCluster `
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" --output tsv
Set-RoleAssignment -PrincipalId $IdentityObjectId -Scope $KvId -Role "Key Vault Secrets User"

Write-Host "== Create the SecretProviderClass - mounts as a file AND syncs to a K8s Secret =="
$spcYaml = @"
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: $SecretProviderClass
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$IdentityClientId"
    keyvaultName: "$KeyVaultName"
    cloudName: ""
    objects: |
      array:
        - |
          objectName: $KvSecretName
          objectType: secret
          objectVersion: ""
    tenantId: "$KvTenantId"
  secretObjects:
  - secretName: $SyncedSecretName
    type: Opaque
    data:
    - objectName: $KvSecretName
      key: MODEL_API_KEY
"@
$spcYaml | kubectl apply -n $Namespace -f -

Write-Host "== Wire the Deployment to mount the CSI volume and source MODEL_API_KEY from the synced Secret =="
# Export first and only add what's needed (not a hand-written minimal
# YAML) - same reasoning as LP02/M02/02-lifecycle-and-probes.ps1: avoid
# accidentally dropping the PVC volume or other config already there.
kubectl get deployment inference-api -n $Namespace -o yaml | Out-File -FilePath /tmp/inference-api-before.yaml -Encoding utf8

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -ne 0) {
    pip install --quiet --user pyyaml 2>$null
    if ($LASTEXITCODE -ne 0) { pip install --quiet --break-system-packages pyyaml 2>$null }
}

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -eq 0) {
    $editScript = @'
import sys, yaml
secret_provider_class, synced_secret = sys.argv[1], sys.argv[2]

with open("/tmp/inference-api-before.yaml") as f:
    doc = yaml.safe_load(f)

pod_spec = doc["spec"]["template"]["spec"]
container = pod_spec["containers"][0]

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
'@
    $editScriptPath = "$env:TEMP\edit-deployment.py"
    Set-Content -Path $editScriptPath -Value $editScript
    python3 $editScriptPath $SecretProviderClass $SyncedSecretName

    kubectl apply -n $Namespace -f /tmp/inference-api-after.yaml
} else {
    Write-Error "PyYAML not available and couldn't be installed - can't safely wire the deployment."
    Write-Error "Install it and re-run, or manually add the CSI volume/mount and update MODEL_API_KEY's secretKeyRef."
    exit 1
}

Write-Host "== Waiting for the rollout (mounting the CSI volume can take longer than a plain config change - RBAC and the driver may still be propagating) =="
kubectl rollout status deployment/inference-api -n $Namespace --timeout=180s
if ($LASTEXITCODE -ne 0) { Write-Warning "rollout did not complete within 180s - check: kubectl describe pod -n $Namespace -l app=inference-api" }

Write-Host ""
Write-Host "== Verify 1: the secret is mounted as a file =="
$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl exec $Pod -n $Namespace -- cat "/mnt/secrets-store/$KvSecretName"
Write-Host ""

Write-Host ""
Write-Host "== Verify 2: the app's own /config endpoint resolved it via the synced K8s Secret =="
kubectl exec $Pod -n $Namespace -- python -c "import urllib.request,json; print(json.load(urllib.request.urlopen('http://localhost:8000/config')))"

Write-Host @"

Suggested Portal checks:
  - Key Vault ($KeyVaultName) -> Secrets: confirm '$KvSecretName' exists.
  - Key Vault -> Access control (IAM) -> Role assignments: confirm the
    add-on's identity (client ID $IdentityClientId) has 'Key Vault
    Secrets User'.
  - AKS cluster -> Settings -> Cluster configuration: confirm "Azure Key
    Vault provider for Secrets Store CSI Driver" shows Enabled.
"@

Write-ElapsedTime
