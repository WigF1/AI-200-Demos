# Tears down what THIS module created: the scheduled purge task, the
# scratch/seed images from 04-seed-untagged-images.ps1, and unlocks the
# v1 tag so it can be deleted later if needed.
#
# What this deliberately does NOT remove: the ACR itself, or the v1
# image. LP01/M02 depends on both to deploy to App Service. If you want
# to remove everything LP01 created (both modules), run
# LP01/99-cleanup-all.ps1 instead, which deletes the whole resource group.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Deleting the scheduled cleanup-untagged ACR task =="
az acr task delete --registry $AcrName --name cleanup-untagged --yes 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no cleanup-untagged task found - already removed or never created)" }

Write-Host "== Removing the scratch tag used to seed untagged manifests =="
az acr repository untag --name $AcrName --image "${ImageName}:scratch" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (no scratch tag found - already removed or never created)" }

Write-Host "== Purging any remaining untagged manifests (leaves 'latest' and any other real tags alone) =="
az acr run --registry $AcrName --cmd "acr purge --filter '${ImageName}:^`$' --untagged --ago 0d" `
  /dev/null --output none 2>$null

Write-Host "== Unlocking v1 so it can be removed by a later full teardown =="
az acr repository update --name $AcrName --image "${ImageName}:${ImageTag}" --write-enabled true 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "  (v1 tag not found or already unlocked)" }

Write-Host ""
Write-Host "Done. Left in place (still needed by LP01/M02): resource group '$ResourceGroup', ACR '$AcrName', image '${ImageName}:${ImageTag}'."
Write-Host "To remove everything for LP01, run: ../../../99-cleanup-all.ps1"

Write-ElapsedTime
