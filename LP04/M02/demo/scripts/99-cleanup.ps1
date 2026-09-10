# Tears down what THIS module created: the vector-enabled container.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the vector container =="
az cosmosdb sql container delete --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $VectorContainerName --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no vector container found)" }

Write-Host ""
Write-Host "Left in place: Cosmos DB account, database, base container, EnableNoSQLVectorSearch capability."
Write-Host "To remove everything for LP04, run: ../../99-cleanup-all.ps1"
