$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

if (-not $Suffix) { $Suffix = "ai200lp06" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp06-redis" }
$RedisName = "redis-$Suffix"
Write-Host "ResourceGroup=$ResourceGroup  RedisName=$RedisName"
