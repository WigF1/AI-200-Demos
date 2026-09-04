# Lab 03 (03-app-svc-sidecar.md): add a sidecar container to the app
# created in 01-deploy-app-service.ps1.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/app-health.ps1

az webapp show --resource-group $ResourceGroup --name $WebAppName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web app '$WebAppName' not found. Run ./01-deploy-app-service.ps1 first."
    exit 1
}

Write-Host "== Convert the app to sidecar-enabled (sitecontainers) mode =="
# --yes suppresses the interactive "are you sure?" confirmation prompt
# this command shows by default. Without it, the prompt (along with any
# way to see or answer it) was going to $null while the command sat
# waiting on stdin forever - looks like a hang, isn't actually one.
az webapp sitecontainers convert --name $WebAppName --resource-group $ResourceGroup --mode sitecontainers --yes
if ($LASTEXITCODE -ne 0) { Write-Host "  (already in sitecontainers mode, or nothing to convert - see any error above)" }

Write-Host "== Write a spec file for a small public 'sidecar' image (this exact image is Microsoft's own public-registry example for sitecontainers) =="
# Schema confirmed against: az webapp sitecontainers create --help (top-level
# "name" + "properties" wrapper) and Microsoft's own tutorial-sidecar.md tip
# for using a public image, which uses this exact image path with this exact
# properties shape. Two mistakes an earlier version of this script had:
# "containerName" instead of "name" at the top level, and all the container
# fields sitting flat at the top level instead of nested under "properties" -
# both caused "Failed to create or update sitecontainer None. Error: No
# value for given attribute" (the "None" was the never-found name).
$specPath = "$env:TEMP\sidecar-spec.json"
$spec = @'
[
  {
    "name": "log-forwarder",
    "properties": {
      "image": "mcr.microsoft.com/appsvc/docs/sidecars/sample-experiment:otel-appinsights-1.0",
      "isMain": false,
      "authType": "Anonymous",
      "volumeMounts": [],
      "environmentVariables": []
    }
  }
]
'@
Set-Content -Path $specPath -Value $spec

# az webapp sitecontainers create isn't idempotent either - it has a
# separate 'update' command for a reason. Simplest re-run-safe approach:
# delete the sidecar first if it's already there, then create fresh from
# the spec file.
az webapp sitecontainers show --name $WebAppName --resource-group $ResourceGroup `
  --container-name log-forwarder --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sidecar 'log-forwarder' already exists - removing so it can be recreated cleanly from the spec file."
    az webapp sitecontainers delete --name $WebAppName --resource-group $ResourceGroup `
      --container-name log-forwarder --output none
}

Write-Host "== Add the sidecar alongside the existing main container =="
az webapp sitecontainers create --name $WebAppName --resource-group $ResourceGroup `
  --sitecontainers-spec-file $specPath

Write-Host "== List containers on the app (main + sidecar) =="
az webapp sitecontainers list --name $WebAppName --resource-group $ResourceGroup --output table

Write-Host "== Restart so the sidecar starts =="
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Verify the main app still serves traffic with the sidecar attached =="
$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
Wait-ForAppHealth -Url "https://$HostName/health" -ExpectHealthy $true | Out-Null

Write-Host ""
Write-Host "== Streaming logs for 15s to catch the sidecar's startup lines =="
$logJob = Start-Job -ScriptBlock { az webapp log tail --resource-group $using:ResourceGroup --name $using:WebAppName }
Start-Sleep -Seconds 15
Receive-Job -Job $logJob
Stop-Job -Job $logJob | Out-Null
Remove-Job -Job $logJob | Out-Null

Write-Host @"

Talk track:
  - Main + sidecar share localhost. A sidecar on port 4318 is reachable
    from the main app at localhost:4318, no extra networking config.
  - App Service only routes external traffic to the isMain=true container.
  - Up to 9 sidecars are supported per Linux app.
  - Roll back:
      az webapp sitecontainers delete --name $WebAppName -g $ResourceGroup --container-name log-forwarder
      az webapp sitecontainers convert --name $WebAppName -g $ResourceGroup --mode docker --yes
"@
