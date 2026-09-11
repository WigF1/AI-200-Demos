# Makes this module runnable without LP06/M01 having run first.

Write-Host "== Ensuring prerequisites for LP06/M03 (Azure Managed Redis cluster) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az extension add --name redisenterprise --upgrade --only-show-errors

az redisenterprise show --name $RedisName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Azure Managed Redis cluster '$RedisName' already exists."
} else {
    Write-Host "Redis cluster not found - creating (this takes several minutes)..."
    # --public-network-access is required as of API version 2025-07-01
    # (confirmed the hard way - see LP06/M01/01-create-redis-cache.ps1
    # for the full explanation of the exact error this avoids).
    Invoke-TimedStep "Azure Managed Redis create" {
        az redisenterprise create `
          --name $RedisName --resource-group $ResourceGroup --location $Location `
          --sku Balanced_B1 `
          --public-network-access Enabled `
          --output table
    }
}

# access-keys-auth's default is changing from Enabled to Disabled in a
# future breaking-change release - set explicitly since these demos are
# key-based (see LP06/M01/01-create-redis-cache.ps1 for the full note).
az redisenterprise database update --cluster-name $RedisName --resource-group $ResourceGroup `
  --access-keys-auth Enabled --output none

Write-Host "Prerequisites ready."
