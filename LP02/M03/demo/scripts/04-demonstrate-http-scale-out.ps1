# Companion to 01-http-scale-rule.ps1: that script only CONFIGURES the scale
# rule - this one actually generates concurrent load and watches replica
# count increase, so the scale rule's effect is visible, not just its config.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

$hasRule = az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query "properties.template.scale.rules[?name=='http-scale-rule']" --output tsv
if (-not $hasRule) {
    Write-Error "No 'http-scale-rule' scale rule found - run ./01-http-scale-rule.ps1 first."
    exit 1
}

$Fqdn = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn --output tsv

Write-Host "== Baseline replica count =="
az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --output table

Write-Host ""
Write-Host "== Generating concurrent load for 90s (20 parallel jobs hitting /classify) =="
$loadJobs = 1..20 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        $endTime = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $endTime) {
            try {
                Invoke-WebRequest -Uri "$url/classify" -Method Post -ContentType "application/json" `
                  -Body '{"text":"scale test payload"}' -TimeoutSec 10 -UseBasicParsing | Out-Null
            } catch {}
        }
    } -ArgumentList "https://$Fqdn"
}

Write-Host "== Polling replica count every 15s while load runs =="
for ($check = 1; $check -le 6; $check++) {
    Start-Sleep -Seconds 15
    $count = az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --query "length(@)" --output tsv
    Write-Host "  t+${check}x15s: $count replica(s)"
}

Write-Host "== Stopping load generators =="
$loadJobs | Stop-Job | Out-Null
$loadJobs | Remove-Job -Force | Out-Null

Write-Host ""
Write-Host "== Final replica list =="
az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --output table
Write-Host "Replicas will scale back down on their own after the cooldown period (no traffic)."
