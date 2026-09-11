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
    Invoke-TimedStep "Azure Managed Redis create" {
        az redisenterprise create `
          --name $RedisName --resource-group $ResourceGroup --location $Location `
          --sku Balanced_B1 `
          --output table
    }
}

Write-Host "Prerequisites ready."
