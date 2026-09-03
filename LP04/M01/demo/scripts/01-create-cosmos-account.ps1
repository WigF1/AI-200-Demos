# Slide 6: Account -> Database -> Container -> Item resource hierarchy.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp04" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp04-cosmosdb" }
$CosmosAccount = "cosmos-$Suffix"
$DatabaseName = "ragstore"
$ContainerName = "documents"

az group create --name $ResourceGroup --location $Location --output table

Write-Host "== Serverless account for demo economics =="
az cosmosdb create `
  --resource-group $ResourceGroup --name $CosmosAccount `
  --locations regionName=$Location failoverPriority=0 isZoneRedundant=false `
  --capabilities EnableServerless `
  --output table

az cosmosdb sql database create `
  --resource-group $ResourceGroup --account-name $CosmosAccount --name $DatabaseName `
  --output table

Write-Host "== Container with categoryId as the partition key =="
az cosmosdb sql container create `
  --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $ContainerName `
  --partition-key-path "/categoryId" `
  --output table

Write-Host "== Connection details for the Python script =="
az cosmosdb show --resource-group $ResourceGroup --name $CosmosAccount --query documentEndpoint --output tsv
az cosmosdb keys list --resource-group $ResourceGroup --name $CosmosAccount --query primaryMasterKey --output tsv
Write-Host "Set `$env:COSMOS_ENDPOINT and `$env:COSMOS_KEY before running crud_and_queries.py"
