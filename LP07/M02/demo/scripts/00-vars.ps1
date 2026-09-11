$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

if (-not $Suffix) { $Suffix = "ai200lp07" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }
$EventGridTopic = "evgt-$Suffix"
Write-Host "ResourceGroup=$ResourceGroup  EventGridTopic=$EventGridTopic"
