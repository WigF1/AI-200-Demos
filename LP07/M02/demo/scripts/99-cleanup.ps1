# Tears down what THIS module created: the Event Grid topic (its event
# subscription goes with it) and the Event Grid Viewer web app + plan.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the Event Grid topic =="
az eventgrid topic delete --resource-group $ResourceGroup --name $EventGridTopic 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Event Grid topic found)" }

Write-Host "== Deleting the Event Grid Viewer web app and its App Service plan =="
az webapp delete --resource-group $ResourceGroup --name $ViewerSite 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no viewer web app found)" }
az appservice plan delete --resource-group $ResourceGroup --name $ViewerPlan --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no viewer App Service plan found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
