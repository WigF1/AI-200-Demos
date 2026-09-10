# Tears down what THIS module created: the container, database, and
# Cosmos DB account. M02/M03 depend on the account/database existing
# (their own 00-ensure-prereqs.ps1 recreates them if missing), so running
# this also affects them - use the LP-level 99-cleanup-all.ps1 instead if
# you're tearing down the whole learning path anyway.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting Cosmos DB account (this also removes its databases/containers) =="
az cosmosdb delete --resource-group $ResourceGroup --name $CosmosAccount --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Cosmos DB account found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
