$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

if (-not $Suffix) { $Suffix = "ai200lp05" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp05-postgresql" }
$PgServer = "pg-$Suffix"
$PgAdminUser = "pgadmin"
$DbName = "agentdb"
# Password persists across runs in a gitignored local file - see the
# bash version's comment for why a freshly-generated password on every
# run breaks the moment the server already exists.
$PgPasswordFile = "$PSScriptRoot/../../../.pg-admin-password"
Write-Host "ResourceGroup=$ResourceGroup  PgServer=$PgServer  DbName=$DbName"
