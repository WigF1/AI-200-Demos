# Slide 17: vector policy set at container creation (immutable after creation).
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

# CORRECTED: the container-create flag is --vector-embeddings, not
# --vector-embedding-policy - confirmed against the official az cosmosdb
# sql container reference (learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/container).
$VectorPolicy = '{"vectorEmbeddings":[{"path":"/embedding","dataType":"float32","dimensions":1536,"distanceFunction":"cosine"}]}'
$IndexingPolicy = '{"indexingMode":"consistent","includedPaths":[{"path":"/*"}],"excludedPaths":[{"path":"/embedding/*"},{"path":"/_etag/?"}],"vectorIndexes":[{"path":"/embedding","type":"diskANN"}]}'

Write-Host "== Enable the EnableNoSQLVectorSearch account capability (needed before creating a vector-policy container) =="
$Capabilities = az cosmosdb show --resource-group $ResourceGroup --name $CosmosAccount --query "capabilities[].name" --output tsv
if ($Capabilities -match "EnableNoSQLVectorSearch") {
    Write-Host "Capability already enabled."
} else {
    az cosmosdb update --resource-group $ResourceGroup --name $CosmosAccount --capabilities EnableNoSQLVectorSearch --output none
    Write-Host "Capability requested. Microsoft's own docs note this can take up to 15 minutes to"
    Write-Host "propagate, even though the request itself is auto-approved - the loop below retries"
    Write-Host "container creation automatically rather than making you wait and re-run by hand."
}

az cosmosdb sql container show --resource-group $ResourceGroup --account-name $CosmosAccount `
  --database-name $DatabaseName --name $VectorContainerName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Container '$VectorContainerName' already exists."
} else {
    Write-Host "== Creating the vector-enabled container (retrying up to ~16 minutes if the capability is still propagating) =="
    $maxAttempts = 32
    $succeeded = $false
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        az cosmosdb sql container create `
          --resource-group $ResourceGroup --account-name $CosmosAccount `
          --database-name $DatabaseName --name $VectorContainerName `
          --partition-key-path "/category" `
          --idx $IndexingPolicy `
          --vector-embeddings $VectorPolicy `
          --output table 2>$env:TEMP\vector-container-error.log
        if ($LASTEXITCODE -eq 0) { $succeeded = $true; break }
        if ($attempt -eq $maxAttempts) {
            Write-Error "Still failing after $maxAttempts attempts - this may not be a propagation delay. Last error:"
            Get-Content "$env:TEMP\vector-container-error.log" | Write-Error
            exit 1
        }
        Write-Host "  attempt $attempt/$maxAttempts`: not ready yet, retrying in 30s..."
        Start-Sleep -Seconds 30
    }
}

Write-Host ""
Write-Host "Vector container ready. Run the Python demo with the same COSMOS_ENDPOINT/COSMOS_KEY"
Write-Host "printed by 01-create-cosmos-account.ps1 (or re-print them: az cosmosdb keys list ...)."

Write-ElapsedTime
