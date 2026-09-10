# There isn't a safe module-scoped cleanup here: removing VECTOR from
# azure.extensions risks clobbering other extensions someone else
# allowlisted on the same server (parameter set replaces the whole
# list), and the extension itself costs nothing to leave allowlisted.
Write-Host "Nothing to clean up at the module level for LP05/M02 - the vector"
Write-Host "extension allowlist entry is harmless to leave in place, and the"
Write-Host "tables it created are removed when the server itself is deleted."
Write-Host "Run ../../M01/demo/scripts/99-cleanup.ps1 or ../../99-cleanup-all.ps1"
Write-Host "to remove the server."
