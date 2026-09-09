# Tears down what THIS module created: the ConfigMap, Secret, PVC, and
# reverts the deployment to the base (unconfigured) version. Leaves the
# AKS cluster and ACR in place since M01/M03 depend on them.
Set-Location $PSScriptRoot
. ./00-vars.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing 2>$null

Write-Host "== Deleting ConfigMap, Secret, PVC =="
kubectl delete configmap inference-api-config -n $Namespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no ConfigMap found)" }
kubectl delete secret inference-api-secret -n $Namespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Secret found)" }
kubectl delete pvc inference-api-data -n $Namespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no PVC found)" }

Write-Host "== Deleting Key Vault CSI integration resources (03-keyvault-csi-integration.ps1) =="
# The SecretProviderClass must be deleted BEFORE disabling the add-on -
# Microsoft's own docs note that disabling with one still in use errors out.
kubectl delete secretproviderclass $SecretProviderClass -n $Namespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no SecretProviderClass found)" }
kubectl delete secret $SyncedSecretName -n $Namespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no synced secret found)" }
az aks disable-addons --resource-group $ResourceGroup --name $AksCluster `
  --addons azure-keyvault-secrets-provider --output none 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (add-on already disabled or never enabled)" }
az keyvault show --name $KeyVaultName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    az keyvault delete --name $KeyVaultName --output none
    az keyvault purge --name $KeyVaultName --location $Location --output none 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  (nothing to purge)" }
} else {
    Write-Host "  (no Key Vault found)"
}

Write-Host ""
Write-Host "Done. Left in place: AKS cluster, ACR, namespace, and the base deployment/services."
Write-Host "To remove everything for LP03, run: ../../../99-cleanup-all.ps1"

Write-ElapsedTime
