# Slide 19, 21: readiness/liveness probes and lifecycle actions
# (deactivate/restart), tuned for AI-style slow startup.
#
# Actually applies probes via YAML and actually runs the lifecycle
# actions - a previous version of this script just printed the commands
# to run manually.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/app-health.ps1

Write-Host "== Export current config, add readiness + liveness probes on /health =="
# Re-submitting the FULL current export (not a hand-written minimal YAML)
# is deliberate: az containerapp update --yaml has documented cases of
# silently dropping fields not present in the file you give it (e.g.
# scale rules, env vars). Exporting first and only adding the probes
# array keeps everything else exactly as it was.
az containerapp show --name $AcaApp --resource-group $ResourceGroup --output yaml | Out-File -FilePath /tmp/aca-app.yaml -Encoding utf8

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -ne 0) {
    pip install --quiet --user pyyaml 2>$null
    if ($LASTEXITCODE -ne 0) { pip install --quiet --break-system-packages pyyaml 2>$null }
}

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -eq 0) {
    $pyScript = @'
import yaml
with open("/tmp/aca-app.yaml") as f:
    doc = yaml.safe_load(f)
container = doc["properties"]["template"]["containers"][0]
container["probes"] = [
    {
        "type": "Readiness",
        "httpGet": {"path": "/health", "port": 8000},
        "initialDelaySeconds": 5,
        "periodSeconds": 5,
        "failureThreshold": 3,
    },
    {
        "type": "Liveness",
        "httpGet": {"path": "/health", "port": 8000},
        "initialDelaySeconds": 15,
        "periodSeconds": 10,
        "failureThreshold": 5,
    },
]
with open("/tmp/aca-app.yaml", "w") as f:
    yaml.safe_dump(doc, f, default_flow_style=False)
'@
    $pyScriptPath = "$env:TEMP\add-probes.py"
    Set-Content -Path $pyScriptPath -Value $pyScript
    python3 $pyScriptPath

    az containerapp update --name $AcaApp --resource-group $ResourceGroup --yaml /tmp/aca-app.yaml --output table

    Write-Host "== Confirm the probes actually landed in the config =="
    az containerapp show --name $AcaApp --resource-group $ResourceGroup `
      --query "properties.template.containers[0].probes" --output json
} else {
    Write-Host "PyYAML not available and couldn't be installed - skipping the probes config step."
    Write-Host "To do this manually: edit /tmp/aca-app.yaml (add a probes: block under"
    Write-Host "properties.template.containers[0]) then run:"
    Write-Host "  az containerapp update -n $AcaApp -g $ResourceGroup --yaml /tmp/aca-app.yaml"
}

$Fqdn = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn --output tsv
Write-Host "== Confirm the app is still healthy after the probe config change =="
Wait-ForAppHealth -Url "https://$Fqdn/health" -ExpectHealthy $true | Out-Null

Write-Host ""
Write-Host "== Lifecycle action: deactivate the current revision (isolates it, safest first step) =="
$LatestRevision = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
az containerapp revision deactivate --revision $LatestRevision --resource-group $ResourceGroup --output none
az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[].{name:name, active:properties.active}" --output table

Write-Host "== Confirm the app is unreachable with its only revision deactivated =="
Wait-ForAppHealth -Url "https://$Fqdn/health" -ExpectHealthy $false -MaxAttempts 6 -DelaySeconds 5 | Out-Null

Write-Host ""
Write-Host "== Lifecycle action: reactivate (broader than deactivate - clears the isolation) =="
az containerapp revision activate --revision $LatestRevision --resource-group $ResourceGroup --output none
Write-Host "== Confirm the app is reachable again =="
Wait-ForAppHealth -Url "https://$Fqdn/health" -ExpectHealthy $true | Out-Null
