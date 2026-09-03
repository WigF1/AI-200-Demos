# Slide 8: scheduled cleanup of untagged images.
# Run 04-seed-untagged-images.ps1 first if you want real matches to purge -
# a brand-new ACR has nothing untagged, so the task would otherwise run
# and report zero deleted images.
#
# --ago 0d (not the slide's 7d) is deliberate for this demo: --ago 7d only
# purges manifests older than 7 days, so anything 04-seed-untagged-images.ps1
# just created would be silently skipped and the effect wouldn't be visible.
# In production, keep --ago 7d (or longer) so you don't race an in-flight
# push that hasn't been re-tagged yet.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Untagged manifests before purge =="
$BeforeCount = az acr manifest list-metadata --registry $AcrName --name $ImageName `
  --query "length([?tags==null || length(tags)==``0``])" --output tsv
Write-Host "Untagged manifest count: $BeforeCount"
if ($BeforeCount -eq "0") {
    Write-Host "Nothing to purge yet - run ./04-seed-untagged-images.ps1 first to see this task actually delete something."
}

$existingTask = az acr task show --registry $AcrName --name cleanup-untagged --output none 2>$null; $taskExists = $?
if ($taskExists) {
    az acr task update --registry $AcrName --name cleanup-untagged `
      --cmd "acr purge --filter '${ImageName}:.*' --untagged --ago 0d" `
      --schedule "0 0 * * 0" --context /dev/null --output none
} else {
    az acr task create --registry $AcrName --name cleanup-untagged `
      --cmd "acr purge --filter '${ImageName}:.*' --untagged --ago 0d" `
      --schedule "0 0 * * 0" --context /dev/null --output none
}

Write-Host "== Running the purge task now (normally fires on the weekly schedule) =="
az acr task run --registry $AcrName --name cleanup-untagged

Write-Host ""
Write-Host "== Untagged manifests after purge =="
$AfterCount = az acr manifest list-metadata --registry $AcrName --name $ImageName `
  --query "length([?tags==null || length(tags)==``0``])" --output tsv
Write-Host "Untagged manifest count: $AfterCount (was $BeforeCount)"
