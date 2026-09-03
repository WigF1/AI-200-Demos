# Slide 8: shows the actual EFFECT of --write-enabled false set in
# 03-tag-version-lock.ps1. Setting the flag is invisible on its own -
# this script proves it by trying to overwrite and then delete the locked
# tag, expecting both to fail, then unlocks and repeats to show they
# succeed once the lock is removed.
#
# Note: unlike the bash version's $ErrorActionPreference-free az calls,
# we don't set -Stop here - az CLI failures return a non-zero exit code
# but don't throw a terminating PowerShell error, so $LASTEXITCODE is
# what we check.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Confirm the tag is currently locked =="
az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" `
  --query "changeableAttributes" --output json

Write-Host ""
Write-Host "== Attempt 1: overwrite the locked tag with a new build (expected to FAIL) =="
az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" `
  --file "$AppDir/Dockerfile" $AppDir --output none 2>$env:TEMP\overwrite-attempt.log
if ($LASTEXITCODE -eq 0) {
    Write-Host "UNEXPECTED: overwrite succeeded - the tag was not actually locked."
} else {
    Write-Host "Blocked, as expected. ACR's response:"
    Get-Content "$env:TEMP\overwrite-attempt.log" -Tail 5
}

Write-Host ""
Write-Host "== Attempt 2: delete the locked tag (expected to FAIL) =="
az acr repository delete --name $AcrName --image "${ImageName}:${ImageTag}" --yes 2>$env:TEMP\delete-attempt.log
if ($LASTEXITCODE -eq 0) {
    Write-Host "UNEXPECTED: delete succeeded - the tag was not actually locked."
} else {
    Write-Host "Blocked, as expected. ACR's response:"
    Get-Content "$env:TEMP\delete-attempt.log" -Tail 5
}

Write-Host ""
Write-Host "== Unlock the tag =="
az acr repository update --name $AcrName --image "${ImageName}:${ImageTag}" --write-enabled true
az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" `
  --query "changeableAttributes" --output json

Write-Host ""
Write-Host "== Attempt 3: overwrite again now that it's unlocked (expected to SUCCEED) =="
az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" `
  --file "$AppDir/Dockerfile" $AppDir --output none
Write-Host "Succeeded - the tag now points at a new manifest."

Write-Host ""
Write-Host "== Re-lock it, since 03-tag-version-lock.ps1's whole point was production protection =="
az acr repository update --name $AcrName --image "${ImageName}:${ImageTag}" --write-enabled false
az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" `
  --query "changeableAttributes" --output json
