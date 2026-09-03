# Shared helper: wait for an RBAC role assignment to propagate before the
# resource that needs it (e.g. a webapp pulling from ACR, or reading a Key
# Vault secret) tries to use it. Role assignments are visible in the ARM
# control plane almost immediately, but the data-plane services that
# actually enforce them (ACR, Key Vault, Storage, etc.) can lag behind by
# up to a couple of minutes. Polling the assignment first avoids a fixed
# multi-minute sleep on every run; the short buffer afterwards covers the
# data-plane lag that polling alone can't see.
#
# Usage: dot-source this file, then:
#   Wait-ForRoleAssignment -PrincipalId $PrincipalId -Scope $Scope -Role "AcrPull"

function Wait-ForRoleAssignment {
    param(
        [Parameter(Mandatory = $true)][string]$PrincipalId,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Role
    )

    $maxAttempts = 12
    $attempt = 0

    Write-Host "Waiting for role assignment to appear: '$Role' on $Scope for principal $PrincipalId ..."
    while (-not (az role assignment list --assignee $PrincipalId --scope $Scope --role $Role --query "[0].id" --output tsv)) {
        $attempt++
        if ($attempt -ge $maxAttempts) {
            Write-Warning "Still not visible after $($maxAttempts * 10)s - continuing anyway (assignment may just be slow to list)."
            break
        }
        Start-Sleep -Seconds 10
    }

    Write-Host "Role assignment visible. Waiting an extra 30s for data-plane propagation (ACR/Key Vault/etc. token caches)..."
    Start-Sleep -Seconds 30
}
