# Makes this module runnable without LP04/M01 having run first.

Write-Host "== Ensuring prerequisites for LP04/M03 (account, database, base container) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az cosmosdb show --resource-group $ResourceGroup --name $CosmosAccount --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Cosmos DB account '$CosmosAccount' already exists."
} else {
    Write-Host "Cosmos DB account not found - creating (this takes several minutes)..."
    Invoke-TimedStep "Cosmos DB account create" {
        az cosmosdb create `
          --resource-group $ResourceGroup --name $CosmosAccount `
          --locations regionName=$Location failoverPriority=0 isZoneRedundant=false `
          --capabilities EnableServerless `
          --output table
    }
}

az cosmosdb sql database show --resource-group $ResourceGroup --account-name $CosmosAccount `
  --name $DatabaseName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database '$DatabaseName' already exists."
} else {
    az cosmosdb sql database create `
      --resource-group $ResourceGroup --account-name $CosmosAccount --name $DatabaseName `
      --output table
}

az cosmosdb sql container show --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $ContainerName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Container '$ContainerName' already exists."
} else {
    az cosmosdb sql container create `
      --resource-group $ResourceGroup --account-name $CosmosAccount `
      --database-name $DatabaseName --name $ContainerName `
      --partition-key-path "/categoryId" `
      --output table
}

Write-Host "Prerequisites ready."
