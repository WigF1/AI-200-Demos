# Slide 6-7: Burstable tier for dev/test, firewall rule for client access,
# Entra-based auth alongside PostgreSQL native auth.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

Write-Host "== Burstable B1ms tier - good fit for dev/test/demo workloads =="
az postgres flexible-server show --resource-group $ResourceGroup --name $PgServer --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "PostgreSQL server '$PgServer' already exists."
    if (Test-Path $PgPasswordFile) {
        $PgAdminPassword = Get-Content $PgPasswordFile -Raw
    } else {
        Write-Warning "server exists but no cached password file was found at $PgPasswordFile"
        Write-Warning "Azure cannot retrieve an existing server's password, only reset it. Resetting now"
        Write-Warning "so this script can still print a working password (this will invalidate the old one):"
        $PgAdminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
        az postgres flexible-server update --resource-group $ResourceGroup --name $PgServer `
          --admin-password $PgAdminPassword --output none
        Set-Content -Path $PgPasswordFile -Value $PgAdminPassword -NoNewline
    }
} else {
    $PgAdminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
    # Cache the password BEFORE attempting creation, not after - if the
    # create command fails for any reason (including a purely cosmetic
    # failure like az's own table-output renderer not supporting this
    # response shape, confirmed to happen in practice), the password
    # must not be lost even though the server itself may already have
    # been created successfully.
    Set-Content -Path $PgPasswordFile -Value $PgAdminPassword -NoNewline
    Invoke-TimedStep "PostgreSQL flexible server create" {
        az postgres flexible-server create `
          --resource-group $ResourceGroup --name $PgServer `
          --location $Location `
          --tier Burstable --sku-name Standard_B1ms `
          --storage-size 32 --version 16 `
          --admin-user $PgAdminUser --admin-password $PgAdminPassword `
          --public-access 0.0.0.0-255.255.255.255 `
          --output none
    }
}

az postgres flexible-server db show --resource-group $ResourceGroup --server-name $PgServer `
  --database-name $DbName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database '$DbName' already exists."
} else {
    az postgres flexible-server db create `
      --resource-group $ResourceGroup --server-name $PgServer --database-name $DbName `
      --output none
}

Write-Host "== Enable Microsoft Entra authentication alongside native auth (Slide 7) =="
$displayName = az ad signed-in-user show --query displayName -o tsv
$objectId = az ad signed-in-user show --query id -o tsv
az postgres flexible-server microsoft-entra-admin create `
  --resource-group $ResourceGroup --server-name $PgServer `
  --display-name $displayName --object-id $objectId --type User 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (skip if already set, or if not run as a user principal / insufficient Graph permissions)" }

Write-Host ""
Write-Host "== Connection details for the Python script =="
Write-Host "`$env:PGHOST = `"$PgServer.postgres.database.azure.com`""
Write-Host "`$env:PGDATABASE = `"$DbName`""
Write-Host "`$env:PGUSER = `"$PgAdminUser`""
Write-Host "`$env:PGPASSWORD = `"$PgAdminPassword`""
Write-Host "`$env:PGSSLMODE = `"require`""
Write-Host "(paste the five lines above into your shell before running schema_and_queries.py)"

Write-ElapsedTime
