# Tears down what THIS module created: the Function App and its storage
# account, plus the document-jobs queue and the app identity's role
# assignment on the LP07/M01 Service Bus namespace. Your own Data Receiver
# role from local-dev-setup is left in place.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Removing the function app identity's Service Bus role assignment =="
# Before deleting the app - afterwards the assignment is orphaned
# ("Unknown" principal) and has to be found and removed by hand.
$PrincipalId = az functionapp identity show --resource-group $ResourceGroup --name $FunctionApp `
  --query principalId --output tsv 2>$null
$SbId = az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace `
  --query id --output tsv 2>$null
if ($PrincipalId -and $SbId) {
    az role assignment delete --assignee $PrincipalId --scope $SbId --role "Azure Service Bus Data Receiver" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  (no role assignment found)" }
} else {
    Write-Host "  (no function app identity or Service Bus namespace found)"
}

Write-Host "== Deleting the '$JobsQueue' queue =="
az servicebus queue delete --resource-group $ResourceGroup --namespace-name $SbNamespace --name $JobsQueue 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no queue found)" }

Write-Host "== Deleting the Function App =="
az functionapp delete --resource-group $ResourceGroup --name $FunctionApp 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Function App found)" }

Write-Host "== Deleting the storage account =="
az storage account delete --resource-group $ResourceGroup --name $StorageAccount --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no storage account found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
