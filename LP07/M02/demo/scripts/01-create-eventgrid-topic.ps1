# Slide 18, 22: custom topic with CloudEvents v1.0 input schema, plus the
# Event Grid Viewer web app that 02-create-event-subscriptions points at.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az eventgrid topic show --resource-group $ResourceGroup --name $EventGridTopic --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Event Grid topic '$EventGridTopic' already exists."
} else {
    az eventgrid topic create `
      --resource-group $ResourceGroup --name $EventGridTopic --location $Location `
      --input-schema cloudeventschemav1_0 `
      --output table
}

Write-Host "== Event Grid Viewer web app: the subscriptions' webhook handler =="
# Microsoft's sample viewer, deployed from its own ARM template: an App
# Service plan + web app built from the GitHub repo. It shows every
# request Event Grid POSTs to /api/updates live in the browser (SignalR).
# NOT re-runnable: redeploying fails with "Conflict with existing ScmType:
# ExternalGit" (the template's sourcecontrols resource can't be re-PUT),
# so skip it once the web app exists. The deployment returns only after
# the app has been built from the repo.
az webapp show --resource-group $ResourceGroup --name $ViewerSite --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Event Grid Viewer web app '$ViewerSite' already exists."
} else {
    Invoke-TimedStep "Event Grid Viewer deploy (builds the app from GitHub)" {
        az deployment group create `
          --resource-group $ResourceGroup --name evgviewer `
          --template-uri $ViewerTemplateUri `
          --parameters siteName=$ViewerSite hostingPlanName=$ViewerPlan sku=$ViewerSku location=$Location `
          --output none
    }
}

Write-Host ""
Write-Host "== Topic endpoint and key for the Python publisher =="
$Endpoint = az eventgrid topic show --resource-group $ResourceGroup --name $EventGridTopic --query endpoint --output tsv
$Key = az eventgrid topic key list --resource-group $ResourceGroup --name $EventGridTopic --query key1 --output tsv
Write-Host "`$env:EVENTGRID_TOPIC_ENDPOINT = `"$Endpoint`""
Write-Host "`$env:EVENTGRID_TOPIC_KEY = `"$Key`""
Write-Host "(paste the two lines above into your shell before running the Python demos)"

Write-Host ""
Write-Host "== NEXT: open the viewer BEFORE creating any subscriptions =="
Write-Host "  1. Browse to https://$ViewerSite.azurewebsites.net and wait for the page to load."
Write-Host "     F1 apps sleep when idle - the first request can take 30s+ to wake it."
Write-Host "  2. Keep that tab open, then run ./02-create-event-subscriptions.ps1"
Write-Host "     Event Grid validates the endpoint as the subscription is created, so the"
Write-Host "     viewer must already be awake to answer, or the create fails."
Write-Host "     This topic is CloudEvents, so validation is an HTTP OPTIONS handshake"
Write-Host "     (WebHook-Request-Origin -> WebHook-Allowed-Origin) that the viewer answers"
Write-Host "     without displaying it. Only Event Grid-schema subscriptions get a visible"
Write-Host "     SubscriptionValidation event. The subscription succeeding is the proof"
Write-Host "     the handshake worked; published events then appear in the viewer live."

Write-ElapsedTime
