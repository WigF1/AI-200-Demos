# Slide 29, 31: selective indexing + composite index for filter+sort.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

$IndexingPolicy = @'
{
  "indexingMode": "consistent",
  "includedPaths": [
    {"path": "/categoryId/?"},
    {"path": "/documentType/?"},
    {"path": "/uploadDate/?"}
  ],
  "excludedPaths": [
    {"path": "/*"},
    {"path": "/embedding/*"}
  ],
  "compositeIndexes": [
    [
      {"path": "/documentType", "order": "ascending"},
      {"path": "/uploadDate", "order": "descending"}
    ]
  ]
}
'@

az cosmosdb sql container update `
  --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $ContainerName `
  --idx $IndexingPolicy `
  --output table

Write-ElapsedTime
