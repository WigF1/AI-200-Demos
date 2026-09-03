# Slide 8: creates the "dangling" untagged manifests that 05-cleanup-untagged
# purges. A fresh ACR has nothing untagged, so the purge task in
# 05-cleanup-untagged has nothing to demonstrate unless we manufacture some
# first - this script does that on purpose, separately, so it can be
# re-run any time to reset the demo.
#
# How an image becomes "untagged": build two throwaway builds under a tag,
# then move that tag onto a newer build. The manifests the tag used to
# point at are still in the registry (still billed, still counted) but no
# tag references them anymore - exactly what `acr purge --untagged` targets.
Set-Location $PSScriptRoot
. ./00-vars.ps1

$ScratchTag = "scratch"

Write-Host "== Build #1 under :$ScratchTag =="
az acr build --registry $AcrName --image "${ImageName}:${ScratchTag}" `
  --file "$AppDir/Dockerfile" $AppDir --output none

Write-Host "== Build #2 - moves :$ScratchTag, orphaning build #1's manifest =="
az acr build --registry $AcrName --image "${ImageName}:${ScratchTag}" `
  --file "$AppDir/Dockerfile" $AppDir --output none

Write-Host "== Build #3 - moves :$ScratchTag again, orphaning build #2's manifest =="
az acr build --registry $AcrName --image "${ImageName}:${ScratchTag}" `
  --file "$AppDir/Dockerfile" $AppDir --output none

Write-Host ""
Write-Host "== Manifests with no tag pointing at them (untagged) =="
az acr manifest list-metadata --registry $AcrName --name $ImageName `
  --query "[?tags==null || length(tags)==``0``].{digest:digest, createdTime:createdTime}" `
  --output table

Write-Host ""
Write-Host "Seed complete. Run ./05-cleanup-untagged.ps1 to purge these."
