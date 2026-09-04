# Shared helper: track and print elapsed time.
#
# Whole-script timing needs two lines in each script: 00-vars.ps1 (dot-
# sourced by every script) captures $Global:AI200StartTime, and each
# script prints elapsed time at the very end via Write-ElapsedTime.
# PowerShell has no clean "always run this on exit" hook for a plain
# top-level script the way bash's EXIT trap does, so unlike the bash
# version this isn't fully automatic - the final Write-ElapsedTime line
# in each script is what makes it show up on the success path. It won't
# print if the script aborts on an unhandled error partway through.
#
# For timing a single slow step (an AKS cluster create, a Container Apps
# environment create, etc.) inside a script, wrap it with Invoke-TimedStep:
#   Invoke-TimedStep "AKS cluster create" { az aks create --resource-group ... }

function Start-ElapsedTimer {
    $Global:AI200StartTime = Get-Date
}

function Write-ElapsedTime {
    if (-not $Global:AI200StartTime) { return }
    $elapsed = (Get-Date) - $Global:AI200StartTime
    Write-Host ""
    Write-Host ("Elapsed: {0}m {1}s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
}

function Invoke-TimedStep {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    $start = Get-Date
    & $Action
    $exitCode = $LASTEXITCODE
    $elapsed = (Get-Date) - $start
    Write-Host ("  [{0}: {1}m {2}s]" -f $Label, [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
    if ($exitCode) { $Global:LASTEXITCODE = $exitCode }
}
