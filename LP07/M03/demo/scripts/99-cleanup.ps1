# Tears down what THIS module created: the Function App and its storage
# account.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the Function App =="
az functionapp delete --resource-group $ResourceGroup --name $FunctionApp 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Function App found)" }

Write-Host "== Deleting the storage account =="
az storage account delete --resource-group $ResourceGroup --name $StorageAccount --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no storage account found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
