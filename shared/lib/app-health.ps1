# Shared helper: poll a /health endpoint and confirm the app is ACTUALLY
# healthy, not just that something answered HTTP 200. Azure App Service
# serves its own default placeholder page (also HTTP 200) while a
# container is starting, restarting, or has failed to start entirely -
# checking the status code alone can't tell that apart from a real
# response from the app's own /health endpoint. This checks the response
# body for the app's own {"status": "healthy", ...} payload (see
# shared/inference-api/app.py's /health route) in addition to the code.
#
# Usage: dot-source this file, then:
#   Wait-ForAppHealth -Url $Url -ExpectHealthy $true
#   Wait-ForAppHealth -Url $Url -ExpectHealthy $false
#   Wait-ForAppHealth -Url $Url -ExpectHealthy $true -MaxAttempts 20 -DelaySeconds 15

function Wait-ForAppHealth {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][bool]$ExpectHealthy,
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 10
    )

    $status = "000"
    $isHealthy = $false

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
            $status = $response.StatusCode
            $isHealthy = ($status -eq 200) -and ($response.Content -match '"status"\s*:\s*"healthy"')
        } catch {
            $status = "000"
            $isHealthy = $false
        }

        if ($isHealthy -eq $ExpectHealthy) {
            Write-Host "HTTP $status, app healthy=$isHealthy (as expected) after $attempt attempt(s)."
            return $true
        }
        Write-Host "  attempt $attempt`: HTTP $status, app healthy=$isHealthy - retrying in ${DelaySeconds}s"
        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Warning "Did not reach expected state (healthy=$ExpectHealthy) after $($MaxAttempts * $DelaySeconds)s (last: HTTP $status, app healthy=$isHealthy)."
    return $false
}
