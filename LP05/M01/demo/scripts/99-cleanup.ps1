# Tears down what THIS module created: the database and PostgreSQL
# server. Also removes the locally cached admin password file, since it
# would be meaningless once the server is gone.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the PostgreSQL flexible server (this also removes its databases) =="
az postgres flexible-server delete --resource-group $ResourceGroup --name $PgServer --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no PostgreSQL server found)" }

Remove-Item -Path $PgPasswordFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
