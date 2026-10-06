# Slide 20, 24: filtered event subscription delivering to the Event Grid
# Viewer deployed by 01-create-eventgrid-topic. Run that first, and have
# the viewer open in a browser BEFORE running this - Event Grid validates
# the endpoint during the create, so the viewer must be awake to answer.
# This topic is CloudEvents, so validation is the CloudEvents webhook
# OPTIONS handshake (WebHook-Request-Origin -> WebHook-Allowed-Origin):
# the viewer answers it but doesn't display it. Only Event Grid-schema
# subscriptions get a POSTed SubscriptionValidation event the viewer shows.
Set-Location $PSScriptRoot
. ./00-vars.ps1

$TopicId = az eventgrid topic show -g $ResourceGroup -n $EventGridTopic --query id -o tsv

Write-Host "== Filtered event subscription: only StringIn data.status = flagged (Slide 24) =="
az eventgrid event-subscription show --name moderation-flagged-sub --source-resource-id $TopicId --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Event subscription 'moderation-flagged-sub' already exists."
} else {
    # The create doesn't return until validation completes - if the viewer
    # is asleep or still starting it fails with a validation error; browse
    # to it, wait for the page to load, and re-run.
    Invoke-TimedStep "Event subscription create (includes endpoint validation)" {
        az eventgrid event-subscription create `
          --name moderation-flagged-sub `
          --source-resource-id $TopicId `
          --endpoint-type webhook `
          --endpoint $ViewerEndpoint `
          --advanced-filter data.status StringIn flagged `
          --output table
    }
}

Write-Host ""
Write-Host "Subscription delivers to $ViewerEndpoint"
Write-Host "Run ../python/publish_events.py and watch https://$ViewerSite.azurewebsites.net"

Write-ElapsedTime
