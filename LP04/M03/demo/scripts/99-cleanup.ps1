# Reverts the indexing policy back to Cosmos DB's default (index
# everything) - the container itself and its data are left in place
# since M01 owns creating/deleting it.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Reverting to the default indexing policy (index all paths) =="
az cosmosdb sql container update --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $ContainerName `
  --idx '{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[]}' `
  --output table 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no container found)" }

Write-Host "== Deleting the three index comparison containers (02-create-index-comparison-containers.ps1) =="
foreach ($container in @($IdxFlatContainer, $IdxQuantizedflatContainer, $IdxDiskannContainer)) {
    az cosmosdb sql container delete --resource-group $ResourceGroup --account-name $CosmosAccount `
      --database-name $DatabaseName --name $container --yes 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  (no '$container' container found)" }
}

Write-Host ""
Write-Host "Left in place: Cosmos DB account, database, container, and its data."
Write-Host "To remove everything for LP04, run: ../../99-cleanup-all.ps1"
