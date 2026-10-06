# Seeds the keys the demo/webapp dynamic-refresh demo reads (no label).
# Re-run any time to reset them to these starting values before a demo.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp08" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp08-secrets-config" }
$AppConfigName = "appcs-$Suffix"

az appconfig show --resource-group $ResourceGroup --name $AppConfigName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "App Configuration store '$AppConfigName' not found - run ./01-create-app-configuration.ps1 first."
    exit 1
}

Write-Host "== Web app settings: TestingApp:DefaultSettings:* =="
function Set-Kv([string]$Name, [string]$Value) {
    az appconfig kv set --name $AppConfigName --key "TestingApp:DefaultSettings:$Name" --value $Value --yes --output none
    Write-Host "  TestingApp:DefaultSettings:$Name = $Value"
}
Set-Kv Color "lightblue"
Set-Kv Font "Arial"
Set-Kv Message "Hello from Azure App Configuration"
Set-Kv FestiveColor "lightgreen"
# The sentinel - the only key the app watches. Its value is arbitrary;
# what matters is that it CHANGES (e.g. 1 -> 2) after editing other keys.
Set-Kv HasChanged "1"

Write-Host "== Feature flag 'xmas' (off) =="
az appconfig feature set --name $AppConfigName --feature xmas --yes --output none
az appconfig feature disable --name $AppConfigName --feature xmas --yes --output none
Write-Host "  xmas = off"

$Endpoint = az appconfig show --resource-group $ResourceGroup --name $AppConfigName --query endpoint --output tsv
Write-Host ""
Write-Host "`$env:APPCONFIG_ENDPOINT = `"$Endpoint`""
Write-Host "(paste the line above into your shell, then: cd ../webapp; dotnet run)"
