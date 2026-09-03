# Slide 6-7: Burstable tier, firewall rule, Entra admin alongside native auth.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp05" }
if (-not $Location) { $Location = "eastus" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp05-postgresql" }
$PgServer = "pg-$Suffix"
$PgAdminUser = "pgadmin"
if (-not $PgAdminPassword) {
    $PgAdminPassword = [System.Convert]::ToBase64String((1..18 | ForEach-Object { Get-Random -Maximum 256 }))
}
$DbName = "agentdb"

az group create --name $ResourceGroup --location $Location --output table

Write-Host "== Burstable B1ms tier =="
az postgres flexible-server create `
  --resource-group $ResourceGroup --name $PgServer `
  --location $Location `
  --tier Burstable --sku-name Standard_B1ms `
  --storage-size 32 --version 16 `
  --admin-user $PgAdminUser --admin-password $PgAdminPassword `
  --public-access 0.0.0.0-255.255.255.255 `
  --output table
Write-Host "Generated admin password (save this): $PgAdminPassword"

az postgres flexible-server db create `
  --resource-group $ResourceGroup --server-name $PgServer --database-name $DbName `
  --output table

Write-Host "== Enable Microsoft Entra authentication alongside native auth =="
$DisplayName = az ad signed-in-user show --query displayName -o tsv
$ObjectId = az ad signed-in-user show --query id -o tsv
try {
  az postgres flexible-server microsoft-entra-admin create `
    --resource-group $ResourceGroup --server-name $PgServer `
    --display-name $DisplayName --object-id $ObjectId --type User
} catch {
  Write-Host "(skip if not run as a user principal / insufficient Graph permissions)"
}

Write-Host "== Connection values for the Python script =="
Write-Host "PGHOST=$PgServer.postgres.database.azure.com"
Write-Host "PGDATABASE=$DbName"
Write-Host "PGUSER=$PgAdminUser"
Write-Host "PGPASSWORD=$PgAdminPassword"
Write-Host "PGSSLMODE=require"
