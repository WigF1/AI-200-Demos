# Tears down what THIS module modified: reverts the FORCE_CRASH_DEMO env
# var if it was left set. Leaves the AKS cluster, ACR, and deployments in
# place since M01/M02 depend on them.
Set-Location $PSScriptRoot
. ./00-vars.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing 2>$null

Write-Host "== Removing FORCE_CRASH_DEMO if it was left set =="
kubectl set env deployment/inference-api -n $Namespace FORCE_CRASH_DEMO- 2>$null

Write-Host ""
Write-Host "Done. Left in place: AKS cluster, ACR, namespace, and deployments."
Write-Host "To remove everything for LP03, run: ../../../99-cleanup-all.ps1"

Write-ElapsedTime
