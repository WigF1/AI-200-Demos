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

# Remove the legacy "log-forwarder" sidecar (the old OTel/AppInsights
# image that crash-loops without an App Insights connection string - see
# the image comment below) if it's still hanging around from before this
# script was fixed. This can't just live in 99-cleanup.ps1: while you're
# iterating on this script directly, a leftover crash-looping container
# stays present and can keep taking the whole site down on every restart,
# regardless of whether the CURRENT sidecar image is fine.
az webapp sitecontainers show --name $WebAppName --resource-group $ResourceGroup `
  --container-name log-forwarder --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "== Removing leftover 'log-forwarder' sidecar from before this script was fixed =="
    az webapp sitecontainers delete --name $WebAppName --resource-group $ResourceGroup `
      --container-name log-forwarder --output none
}

Write-Host "== Convert the app to sidecar-enabled (sitecontainers) mode =="
# --yes suppresses the interactive "are you sure?" confirmation prompt
# this command shows by default. Without it, the prompt (along with any
# way to see or answer it) was going to $null while the command sat
# waiting on stdin forever - looks like a hang, isn't actually one.
az webapp sitecontainers convert --name $WebAppName --resource-group $ResourceGroup --mode sitecontainers --yes
if ($LASTEXITCODE -ne 0) { Write-Host "  (already in sitecontainers mode, or nothing to convert - see any error above)" }

Write-Host "== Write a spec file for a small public sidecar image =="
# Schema confirmed against: az webapp sitecontainers create --help (top-level
# "name" + "properties" wrapper).
#
# Image: this used to be mcr.microsoft.com/appsvc/docs/sidecars/sample-
# experiment:otel-appinsights-1.0 (also from Microsoft's own docs, as a
# "public image" schema example) - but that image is a real OpenTelemetry
# Collector pre-configured to export to Azure Monitor, and it refuses to
# start at all without an Application Insights connection string:
#   Error: failed to build pipelines: failed to create "azuremonitor"
#   exporter for data type "logs": ConnectionString and InstrumentationKey
#   cannot be empty
# It crash-looped (confirmed via `az webapp sitecontainers status`:
# Status=Terminated, ExitCode=1, RunCount=3) and appeared to take the
# whole site down with it, not just itself - main + sidecars share one
# site-unit lifecycle, so a crash-looping sidecar can make the otherwise-
# healthy main container unreachable too.
#
# mcr.microsoft.com/appsvc/staticsite:latest is Microsoft's OTHER public-
# image example from the same docs, used there as a full isMain
# replacement - a plain static web server with no external dependencies,
# nothing to crash on.
$specPath = "$env:TEMP\sidecar-spec.json"
$spec = @"
[
  {
    "name": "$SidecarName",
    "properties": {
      "image": "mcr.microsoft.com/appsvc/staticsite:latest",
      "isMain": false,
      "authType": "Anonymous",
      "targetPort": "80",
      "volumeMounts": [],
      "environmentVariables": []
    }
  }
]
"@
Set-Content -Path $specPath -Value $spec

# az webapp sitecontainers create isn't idempotent either - it has a
# separate 'update' command for a reason. Simplest re-run-safe approach:
# delete the sidecar first if it's already there, then create fresh from
# the spec file.
az webapp sitecontainers show --name $WebAppName --resource-group $ResourceGroup `
  --container-name $SidecarName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sidecar '$SidecarName' already exists - removing so it can be recreated cleanly from the spec file."
    az webapp sitecontainers delete --name $WebAppName --resource-group $ResourceGroup `
      --container-name $SidecarName --output none
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
Write-Host "== Sidecar status (this is what actually answers 'did it start?' - az webapp log tail only streams the MAIN container's logs, never a sidecar's) =="
# Not filtering with --query here: the exact field name in this command's
# JSON output isn't confirmed against documentation (no example schema
# available), so showing the full object is the honest choice rather than
# guessing a field name that might not exist. Look for "Status": "Running"
# - "Terminated" with a non-zero ExitCode means it crashed, same as the
# OTel image above did.
Start-Sleep -Seconds 10
az webapp sitecontainers status --name $WebAppName --resource-group $ResourceGroup `
  --container-name $SidecarName --output json
if ($LASTEXITCODE -ne 0) { Write-Host "  (status not available yet - try again in a few seconds)" }

Write-Host ""
Write-Host "== Sidecar's own startup logs (the container-specific equivalent of 'log tail') =="
# Wrapped in a background job with a timeout: this command can hang
# instead of returning promptly when there's nothing to fetch yet (e.g. a
# 404 because the container never started) - same class of unbounded-
# blocking issue as the confirmation prompt earlier in this script.
$logJob = Start-Job -ScriptBlock {
    az webapp sitecontainers log --name $using:WebAppName --resource-group $using:ResourceGroup --container-name $using:SidecarName
}
if (Wait-Job -Job $logJob -Timeout 20) {
    Receive-Job -Job $logJob
} else {
    Write-Host "  (command timed out after 20s - the sidecar may still be starting)"
}
Stop-Job -Job $logJob | Out-Null
Remove-Job -Job $logJob -Force | Out-Null
Write-Host "  Re-run manually if needed: az webapp sitecontainers log --name $WebAppName -g $ResourceGroup --container-name $SidecarName"

Write-Host @"

Talk track:
  - Main ("main") + sidecar ("$SidecarName") share localhost. This
    sidecar listens on port 80, so the main app could reach it at
    localhost:80 without any extra networking config.
  - App Service only routes external traffic to the isMain=true container.
  - Up to 9 sidecars are supported per Linux app.
  - A crash-looping sidecar can take the whole site down, not just
    itself - main + sidecars share one site-unit lifecycle. Always
    check "az webapp sitecontainers status" for a new sidecar image
    before assuming a main-app outage is unrelated to it.
  - Roll back:
      az webapp sitecontainers delete --name $WebAppName -g $ResourceGroup --container-name $SidecarName
      az webapp sitecontainers convert --name $WebAppName -g $ResourceGroup --mode docker --yes
"@
