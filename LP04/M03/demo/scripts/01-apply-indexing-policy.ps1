# Slide 29, 31: selective indexing + composite index for filter+sort.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp04" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp04-cosmosdb" }
$CosmosAccount = "cosmos-$Suffix"
$DatabaseName = "ragstore"
$ContainerName = "documents"

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
