# Tears down what THIS module created: the Service Bus namespace (queue,
# topic, and subscriptions all go with it).
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the Service Bus namespace =="
az servicebus namespace delete --resource-group $ResourceGroup --name $SbNamespace 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Service Bus namespace found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
