# Reverts the two tuned server parameters back to PostgreSQL's own
# defaults (random_page_cost=4, work_mem=4096 KB / 4MB). The server
# itself is left in place since M01 owns creating/deleting it.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Reverting random_page_cost and work_mem to PostgreSQL defaults =="
az postgres flexible-server parameter set --resource-group $ResourceGroup --server-name $PgServer `
  --name random_page_cost --value "4" --output none 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no server found)" }
az postgres flexible-server parameter set --resource-group $ResourceGroup --server-name $PgServer `
  --name work_mem --value "4096" --output none 2>$null

Write-Host ""
Write-Host "Left in place: PostgreSQL server, database, and its data."
Write-Host "To remove everything for LP05, run: ../../99-cleanup-all.ps1"
