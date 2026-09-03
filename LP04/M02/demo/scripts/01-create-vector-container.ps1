# Slide 17: vector policy set at container creation (immutable after creation).
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp04" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp04-cosmosdb" }
$CosmosAccount = "cosmos-$Suffix"
$DatabaseName = "ragstore"
$ContainerName = "doc_embeddings"

$VectorPolicy = '{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":1536,"distanceFunction":"cosine"}]}'
$IndexingPolicy = '{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[{"path":"/embedding/*"},{"path":"/\"_etag\"/?"}],"vectorIndexes":[{"path":"/embedding","type":"diskANN"}]}'

az cosmosdb sql container create `
  --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $ContainerName `
  --partition-key-path "/category" `
  --idx $IndexingPolicy `
  --vector-embedding-policy $VectorPolicy `
  --output table
