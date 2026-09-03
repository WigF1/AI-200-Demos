# Slide 6: Azure Managed Redis, Balanced tier (4:1 memory:vCPU) for standard workloads.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp06" }
if (-not $Location) { $Location = "eastus" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp06-redis" }
$RedisName = "redis-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az extension add --name redisenterprise --upgrade --only-show-errors

Write-Host "== Balanced_B1: 4:1 memory-to-vCPU ratio =="
az redisenterprise create `
  --name $RedisName --resource-group $ResourceGroup --location $Location `
  --sku Balanced_B1 `
  --output table

Write-Host "== Endpoint (port 10000, TLS) and access key for the Python script =="
az redisenterprise show --name $RedisName --resource-group $ResourceGroup --query hostName --output tsv
az redisenterprise database list-keys --cluster-name $RedisName --resource-group $ResourceGroup --query primaryKey --output tsv
