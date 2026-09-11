# Tears down what THIS module created: the Azure Managed Redis cluster
# (and its one database, deleted along with it).
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the Azure Managed Redis cluster =="
az redisenterprise delete --name $RedisName --resource-group $ResourceGroup --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no Redis cluster found)" }

Write-Host ""
Write-Host "Resource group '$ResourceGroup' itself was left in place."
Write-Host "To remove it too, run: ../../99-cleanup-all.ps1"
