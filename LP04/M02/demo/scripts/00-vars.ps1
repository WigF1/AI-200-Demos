$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

if (-not $Suffix) { $Suffix = "ai200lp04" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp04-cosmosdb" }
$CosmosAccount = "cosmos-$Suffix"
$DatabaseName = "ragstore"
$ContainerName = "documents"
$VectorContainerName = "doc_embeddings"
Write-Host "ResourceGroup=$ResourceGroup  CosmosAccount=$CosmosAccount  VectorContainerName=$VectorContainerName"
