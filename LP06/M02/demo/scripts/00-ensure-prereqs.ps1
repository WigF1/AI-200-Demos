# Makes this module runnable without LP06/M01 having run first.

Write-Host "== Ensuring prerequisites for LP06/M02 (Azure Managed Redis cluster) =="

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
    # --clustering-policy EnterpriseCluster - default is OSSCluster, which
    # requires a cluster-aware client and produces MovedError against the
    # plain redis.Redis() these demos use. See
    # LP06/M01/01-create-redis-cache.ps1 for the full explanation.
    # Immutable after creation.
    # --modules name=RediSearch - required by LP06/M03 (FT.CREATE etc.);
    # confirmed the hard way that without it every FT.* command fails with
    # "unknown command 'FT.CREATE'". Modules can ONLY be added at creation
    # time. RediSearch also requires --eviction-policy NoEviction (default
    # is VolatileLRU; Azure docs list NoEviction as required for RediSearch).
    # Both immutable - an existing cluster without them must be deleted
    # (LP06/M01/demo/scripts/99-cleanup) and recreated.
    Invoke-TimedStep "Azure Managed Redis create" {
        az redisenterprise create `
          --name $RedisName --resource-group $ResourceGroup --location $Location `
          --sku Balanced_B1 `
          --public-network-access Enabled `
          --clustering-policy EnterpriseCluster `
          --modules name=RediSearch `
          --eviction-policy NoEviction `
          --output table
    }
}

# access-keys-auth's default is changing from Enabled to Disabled in a
# future breaking-change release - set explicitly since these demos are
# key-based (see LP06/M01/01-create-redis-cache.ps1 for the full note).
az redisenterprise database update --cluster-name $RedisName --resource-group $ResourceGroup `
  --access-keys-auth Enabled --output none

Write-Host "Prerequisites ready."
