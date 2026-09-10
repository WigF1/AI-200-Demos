# Makes this module runnable without LP05/M01 having run first.

Write-Host "== Ensuring prerequisites for LP05/M02 (server, database) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az postgres flexible-server show --resource-group $ResourceGroup --name $PgServer --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "PostgreSQL server '$PgServer' already exists."
    if (Test-Path $PgPasswordFile) {
        $PgAdminPassword = Get-Content $PgPasswordFile -Raw
    } else {
        Write-Warning "server exists but no cached password file was found at $PgPasswordFile"
        Write-Warning "Resetting the admin password so this script can still produce a working one:"
        $PgAdminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
        az postgres flexible-server update --resource-group $ResourceGroup --name $PgServer `
          --admin-password $PgAdminPassword --output none
        Set-Content -Path $PgPasswordFile -Value $PgAdminPassword -NoNewline
    }
} else {
    Write-Host "PostgreSQL server not found - creating (this takes several minutes)..."
    $PgAdminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
    Invoke-TimedStep "PostgreSQL flexible server create" {
        az postgres flexible-server create `
          --resource-group $ResourceGroup --name $PgServer `
          --location $Location `
          --tier Burstable --sku-name Standard_B1ms `
          --storage-size 32 --version 16 `
          --admin-user $PgAdminUser --admin-password $PgAdminPassword `
          --public-access 0.0.0.0-255.255.255.255 `
          --output table
    }
    Set-Content -Path $PgPasswordFile -Value $PgAdminPassword -NoNewline
}

az postgres flexible-server db show --resource-group $ResourceGroup --server-name $PgServer `
  --database-name $DbName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database '$DbName' already exists."
} else {
    az postgres flexible-server db create `
      --resource-group $ResourceGroup --server-name $PgServer --database-name $DbName `
      --output table
}

Write-Host "Prerequisites ready."
