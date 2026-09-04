# Tears down what THIS module created/modified. Since M02 only updates
# the container app M01 (or this module's own bootstrap) created rather
# than creating separate resources, this deletes the container app
# itself - leaving the environment, ACR, and image in place since other
# modules (and a fresh M01 run) can reuse them.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the container app =="
az containerapp delete --name $AcaApp --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no container app found)" }

Write-Host ""
Write-Host "Done. Left in place: resource group '$ResourceGroup', Container Apps environment, ACR, and image."
Write-Host "To remove everything for LP02, run: ../../../99-cleanup-all.ps1"
