# Tears down what THIS module created: the Service Bus namespace/queue.
# Leaves the container app, environment, and ACR in place since M01/M02
# depend on them. Also resets the container app's scale rules back to a
# single always-on replica so it doesn't sit at 0 or mid-scale-test state.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Resetting scale rules and revision mode =="
az containerapp update --name $AcaApp --resource-group $ResourceGroup `
  --min-replicas 1 --max-replicas 3 --output none 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no container app found)" }
az containerapp revision set-mode --name $AcaApp --resource-group $ResourceGroup --mode single --output none 2>$null

Write-Host "== Deleting the Service Bus namespace (includes the queue) =="
az servicebus namespace delete --name $ServiceBusNamespace --resource-group $ResourceGroup 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Service Bus namespace found)" }

Write-Host ""
Write-Host "Done. Left in place: resource group '$ResourceGroup', container app, environment, ACR."
Write-Host "To remove everything for LP02, run: ../../../99-cleanup-all.ps1"

Write-ElapsedTime
