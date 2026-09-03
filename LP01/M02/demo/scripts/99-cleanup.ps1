# Tears down what THIS module created: the sidecar, the staging slot, the
# web app, the App Service plan, and the Key Vault.
#
# What this deliberately does NOT remove: the resource group and the ACR
# from LP01/M01 (M01's cleanup script, and this LP's, don't assume which
# order you'll tear down in). If you want to remove everything LP01
# created (both modules), run LP01/99-cleanup-all.ps1 instead, which
# deletes the whole resource group in one step.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Removing the sidecar (if present) and reverting to single-container mode =="
az webapp sitecontainers delete --name $WebAppName --resource-group $ResourceGroup `
  --container-name log-forwarder 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no sidecar found)" }
az webapp sitecontainers convert --name $WebAppName --resource-group $ResourceGroup --mode docker 2>$null

Write-Host "== Deleting the staging slot =="
az webapp deployment slot delete --resource-group $ResourceGroup --name $WebAppName `
  --slot $StagingSlotName 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no staging slot found)" }

Write-Host "== Deleting the web app =="
az webapp delete --resource-group $ResourceGroup --name $WebAppName 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no web app found)" }

Write-Host "== Deleting the App Service plan =="
az appservice plan delete --resource-group $ResourceGroup --name $AppServicePlan --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no App Service plan found)" }

Write-Host "== Deleting the Key Vault (soft-deleted by default; purging so the name is free to reuse) =="
az keyvault delete --resource-group $ResourceGroup --name $KeyVaultName 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Key Vault found)" }
az keyvault purge --name $KeyVaultName --location $Location 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (nothing to purge)" }

Write-Host ""
Write-Host "Done. Left in place: resource group '$ResourceGroup' and ACR '$AcrName' (owned by LP01/M01)."
Write-Host "To remove everything for LP01, run: ../../../99-cleanup-all.ps1"
