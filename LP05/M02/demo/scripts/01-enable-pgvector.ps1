# Slide 17: pgvector must be allowlisted at the server level before CREATE EXTENSION works.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp05" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp05-postgresql" }
$PgServer = "pg-$Suffix"

az postgres flexible-server parameter set `
  --resource-group $ResourceGroup --server-name $PgServer `
  --name azure.extensions --value "VECTOR" `
  --output table

Write-Host "Now connect (e.g. psql or the Python script) and run: CREATE EXTENSION IF NOT EXISTS vector;"
