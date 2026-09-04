# Tears down what THIS module created: the AKS cluster and ACR.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the AKS cluster (this takes several minutes) =="
az aks delete --resource-group $ResourceGroup --name $AksCluster --yes --no-wait 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no AKS cluster found)" }

Write-Host "== Deleting the ACR =="
az acr delete --name $AcrName --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no ACR found)" }

Write-Host ""
Write-Host "AKS deletion was started with --no-wait - it'll finish in the background."
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too (and not wait on the AKS deletion first), run: ../../../99-cleanup-all.ps1"

Write-ElapsedTime
