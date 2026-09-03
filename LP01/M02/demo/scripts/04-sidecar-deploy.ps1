# Lab 03 (03-app-svc-sidecar.md): add a sidecar container to the app
# created in 01-deploy-app-service.ps1.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Convert the app to sidecar-enabled (sitecontainers) mode =="
az webapp sitecontainers convert --name $WebAppName --resource-group $ResourceGroup --mode sitecontainers

Write-Host "== Write a spec file for a small sample sidecar image =="
$specPath = "$env:TEMP\sidecar-spec.json"
$spec = @'
[
  {
    "containerName": "log-forwarder",
    "image": "mcr.microsoft.com/appsvc/docs/sidecars/sample-experiment:otel-appinsights-1.0",
    "isMain": false,
    "authType": "Anonymous",
    "startUpCommand": "",
    "targetPort": "",
    "volumeMounts": [],
    "environmentVariables": []
  }
]
'@
Set-Content -Path $specPath -Value $spec

Write-Host "== Add the sidecar alongside the existing main container =="
az webapp sitecontainers create --name $WebAppName --resource-group $ResourceGroup `
  --sitecontainers-spec-file $specPath

Write-Host "== List containers on the app (main + sidecar) =="
az webapp sitecontainers list --name $WebAppName --resource-group $ResourceGroup --output table

Write-Host "== Restart so the sidecar starts =="
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host @"

Talk track:
  - Main + sidecar share localhost. A sidecar on port 4318 is reachable
    from the main app at localhost:4318, no extra networking config.
  - App Service only routes external traffic to the isMain=true container.
  - Up to 9 sidecars are supported per Linux app.
  - Roll back:
      az webapp sitecontainers delete --name $WebAppName -g $ResourceGroup --container-name log-forwarder
      az webapp sitecontainers convert --name $WebAppName -g $ResourceGroup --mode docker
"@
