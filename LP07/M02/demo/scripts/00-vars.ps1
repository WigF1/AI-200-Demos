$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

if (-not $Suffix) { $Suffix = "ai200lp07" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }
$EventGridTopic = "evgt-$Suffix"
Write-Host "ResourceGroup=$ResourceGroup  EventGridTopic=$EventGridTopic"
# Event Grid Viewer sample (github.com/Azure-Samples/azure-event-grid-viewer)
# - the webhook handler the event subscriptions deliver to. Site name is
# global (<name>.azurewebsites.net), hence the suffix.
$ViewerSite = "evgviewer-$Suffix"
$ViewerPlan = "asp-evgviewer-$Suffix"
if (-not $ViewerSku) { $ViewerSku = "F1" }
$ViewerTemplateUri = "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/main/azuredeploy.json"
$ViewerEndpoint = "https://$ViewerSite.azurewebsites.net/api/updates"
