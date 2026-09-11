# Slide 6: Azure Managed Redis, Balanced tier (4:1 memory:vCPU) for standard workloads.
#
# Current best practice per Microsoft's own docs (learn.microsoft.com/
# en-us/azure/redis/scripts/create-manage-cache, checked 2026): "Use
# Microsoft Entra ID with managed identities to authorize requests
# against your cache if possible - it provides better security and is
# easier to use than shared access key authorization." This demo uses
# access keys throughout to match the deck's own teaching content and
# keep the Python demos approachable, but for anything beyond a training
# exercise, prefer Entra ID auth (see az redisenterprise database
# access-policy-assignment create) and managed identities instead.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az extension add --name redisenterprise --upgrade --only-show-errors

Write-Host "== Balanced_B1: 4:1 memory-to-vCPU ratio, good default for AI workloads =="
# az redisenterprise create's own reference description warns it will
# "overwrite/recreate, with potential downtime" an existing cluster
# rather than being a safe no-op - unlike many other az create commands,
# this one is NOT safely re-runnable without an explicit existence check.
az redisenterprise show --name $RedisName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Azure Managed Redis cluster '$RedisName' already exists."
} else {
    Invoke-TimedStep "Azure Managed Redis create" {
        az redisenterprise create `
          --name $RedisName --resource-group $ResourceGroup --location $Location `
          --sku Balanced_B1 `
          --output table
    }
}

Write-Host ""
Write-Host "== Connection details for the Python scripts =="
$HostName = az redisenterprise show --name $RedisName --resource-group $ResourceGroup --query hostName --output tsv
$Key = az redisenterprise database list-keys --cluster-name $RedisName --resource-group $ResourceGroup --query primaryKey --output tsv
Write-Host "`$env:REDIS_HOST = `"$HostName`""
Write-Host "`$env:REDIS_KEY = `"$Key`""
Write-Host "(paste the two lines above into your shell before running any of the Python demos)"

Write-ElapsedTime
