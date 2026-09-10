# Slide 17: pgvector must be allowlisted at the server level before CREATE EXTENSION works.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

Write-Host "== Allowlisting the vector extension (appending, not overwriting, any existing allowlist) =="
$CurrentExtensions = az postgres flexible-server parameter show --resource-group $ResourceGroup `
  --server-name $PgServer --name azure.extensions --query value --output tsv

if ($CurrentExtensions -and ($CurrentExtensions -split ',' | Where-Object { $_.Trim() -ieq "VECTOR" })) {
    Write-Host "VECTOR is already allowlisted (current value: $CurrentExtensions)."
} else {
    if ([string]::IsNullOrEmpty($CurrentExtensions)) {
        $NewExtensions = "VECTOR"
    } else {
        $NewExtensions = "$CurrentExtensions,VECTOR"
    }
    az postgres flexible-server parameter set `
      --resource-group $ResourceGroup --server-name $PgServer `
      --name azure.extensions --value $NewExtensions `
      --output table
}

Write-Host "Now connect (e.g. psql or the Python script) and run: CREATE EXTENSION IF NOT EXISTS vector;"

Write-ElapsedTime
