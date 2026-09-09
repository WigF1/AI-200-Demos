# Slide 34: multiple revision mode + weighted traffic split (canary/blue-green).
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

az containerapp revision set-mode --name $AcaApp --resource-group $ResourceGroup --mode multiple

Write-Host "== Current revisions =="
$RevisionCount = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "length(@)" --output tsv
if ([int]$RevisionCount -lt 2) {
    Write-Host "Only $RevisionCount revision(s) exist - creating a second one (revision-scope"
    Write-Host "env var change) so there's something to split traffic between."
    az containerapp update --name $AcaApp --resource-group $ResourceGroup `
      --set-env-vars "IMAGE_VERSION=v2-canary" --output none
}
az containerapp revision list --name $AcaApp --resource-group $ResourceGroup `
  --query "[].{name:name, active:properties.active}" --output table

# Identify which revision is the canary by the trait we actually control
# (the IMAGE_VERSION=v2-canary env var set above), not by position in the
# list - az containerapp revision list's ordering isn't newest-first as
# might be assumed (confirmed the hard way: an earlier version of this
# script used [0]/[1] and ended up applying the weights backwards - the
# pre-existing revision got labeled "latest" and the just-created canary
# got labeled "previous", so the canary ended up with 80% of traffic
# instead of the intended 20%).
$CanaryRevision = $null
$StableRevision = $null
$allRevisions = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[].name" --output tsv
foreach ($rev in $allRevisions) {
    $imgVer = az containerapp revision show --name $AcaApp --resource-group $ResourceGroup --revision $rev `
      --query "properties.template.containers[0].env[?name=='IMAGE_VERSION'].value | [0]" --output tsv 2>$null
    if ($imgVer -eq "v2-canary") {
        $CanaryRevision = $rev
    } elseif (-not $StableRevision) {
        $StableRevision = $rev
    }
}

if (-not $CanaryRevision -or -not $StableRevision) {
    Write-Error "Could not identify both a canary and a stable revision - check: az containerapp revision list -n $AcaApp -g $ResourceGroup"
    exit 1
}

Write-Host "== 20/80 canary split: $CanaryRevision (v2-canary) gets 20%, $StableRevision gets 80% =="
az containerapp ingress traffic set --name $AcaApp --resource-group $ResourceGroup `
  --revision-weight "${CanaryRevision}=20" "${StableRevision}=80" `
  --output table

Write-Host ""
Write-Host "== Proving the split actually happens: 30 requests, tallied by imageVersion =="
$Fqdn = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn --output tsv
$CanaryHits = 0
$OtherHits = 0
for ($i = 1; $i -le 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "https://$Fqdn/config" -UseBasicParsing -TimeoutSec 10
        $version = ($response.Content | ConvertFrom-Json).imageVersion
    } catch {
        $version = "?"
    }
    if ($version -eq "v2-canary") { $CanaryHits++ } else { $OtherHits++ }
}
Write-Host "canary (v2-canary): $CanaryHits/30 requests (~$([math]::Round($CanaryHits * 100 / 30))%, configured 20%)"
Write-Host "other:               $OtherHits/30 requests (~$([math]::Round($OtherHits * 100 / 30))%, configured 80%)"
Write-Host "(small sample - expect noise around the configured weights, not an exact match)"

Write-ElapsedTime
