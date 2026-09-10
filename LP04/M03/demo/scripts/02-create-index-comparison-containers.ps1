# Slide 30: create one container per vector index type (flat, quantizedFlat,
# diskANN) with identical vector policies otherwise, so
# compare_index_types.py can seed the same data into each and measure
# real differences. Vector policies (including index type) are immutable
# after creation - this is why the comparison needs three containers,
# not one container reconfigured three times.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

# 384 dimensions, not 1536 like M02's example - "flat" caps out at 505
# dimensions (Slide 30), so all three containers need to share a
# dimension count under that limit for the comparison to be apples-to-
# apples (and for the flat container to be creatable at all). 384
# matches common smaller embedding models in practice.
$VectorPolicy = '{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":384,"distanceFunction":"cosine"}]}'

Write-Host "== Enable the EnableNoSQLVectorSearch account capability (needed before creating a vector-policy container) =="
$Capabilities = az cosmosdb show --resource-group $ResourceGroup --name $CosmosAccount --query "capabilities[].name" --output tsv
if ($Capabilities -match "EnableNoSQLVectorSearch") {
    Write-Host "Capability already enabled."
} else {
    az cosmosdb update --resource-group $ResourceGroup --name $CosmosAccount --capabilities EnableNoSQLVectorSearch --output none
    Write-Host "Capability requested. This can take up to 15 minutes to propagate - the loop"
    Write-Host "below retries container creation automatically rather than making you re-run by hand."
}

function New-VectorIndexContainer {
    param([string]$ContainerName, [string]$IndexType)

    $indexingPolicy = "{`"indexingMode`":`"consistent`",`"includedPaths`":[{`"path`":`"/*`"}],`"excludedPaths`":[{`"path`":`"/embedding/*`"},{`"path`":`"/_etag/?`"}],`"vectorIndexes`":[{`"path`":`"/embedding`",`"type`":`"$IndexType`"}]}"

    az cosmosdb sql container show --resource-group $ResourceGroup --account-name $CosmosAccount `
      --database-name $DatabaseName --name $ContainerName --output none 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Container '$ContainerName' ($IndexType) already exists."
        return
    }

    Write-Host "== Creating '$ContainerName' with a $IndexType vector index (retrying up to ~16 minutes if the capability is still propagating) =="
    $maxAttempts = 32
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        az cosmosdb sql container create `
          --resource-group $ResourceGroup --account-name $CosmosAccount `
          --database-name $DatabaseName --name $ContainerName `
          --partition-key-path "/category" `
          --idx $indexingPolicy `
          --vector-embeddings $VectorPolicy `
          --output table 2>$env:TEMP\idx-container-error.log
        if ($LASTEXITCODE -eq 0) { return }
        if ($attempt -eq $maxAttempts) {
            Write-Error "Still failing after $maxAttempts attempts - this may not be a propagation delay. Last error:"
            Get-Content "$env:TEMP\idx-container-error.log" | Write-Error
            exit 1
        }
        Write-Host "  attempt $attempt/$maxAttempts`: not ready yet, retrying in 30s..."
        Start-Sleep -Seconds 30
    }
}

New-VectorIndexContainer -ContainerName $IdxFlatContainer -IndexType "flat"
New-VectorIndexContainer -ContainerName $IdxQuantizedflatContainer -IndexType "quantizedFlat"
New-VectorIndexContainer -ContainerName $IdxDiskannContainer -IndexType "diskANN"

Write-Host ""
Write-Host "All three containers ready. Run compare_index_types.py with the same COSMOS_ENDPOINT/"
Write-Host "COSMOS_KEY printed by 01-create-cosmos-account.ps1."

Write-ElapsedTime
