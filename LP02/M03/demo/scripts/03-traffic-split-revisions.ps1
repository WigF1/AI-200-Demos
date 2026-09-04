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

$Latest = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
$Previous = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[1].name" --output tsv

Write-Host "== 20/80 canary split: $Latest gets 20%, $Previous gets 80% =="
az containerapp ingress traffic set --name $AcaApp --resource-group $ResourceGroup `
  --revision-weight "${Latest}=20" "${Previous}=80" `
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
