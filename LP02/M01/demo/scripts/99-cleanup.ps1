# Tears down what THIS module created: the container app, Container Apps
# environment, Log Analytics workspace, and ACR.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the container app =="
az containerapp delete --name $AcaApp --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no container app found)" }

Write-Host "== Deleting the Container Apps environment =="
az containerapp env delete --name $AcaEnv --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no environment found)" }

Write-Host "== Deleting the Log Analytics workspace =="
az monitor log-analytics workspace delete --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --yes --force true 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no workspace found)" }

Write-Host "== Deleting the ACR =="
az acr delete --name $AcrName --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no ACR found)" }

Write-Host ""
Write-Host "Done. Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../../99-cleanup-all.ps1"
