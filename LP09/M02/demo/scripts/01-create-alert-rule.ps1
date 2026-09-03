# Slide 23-24: log search alert rule + action group.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp09" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp09-observe" }
$AppInsights = "appi-$Suffix"
$ActionGroup = "ag-$Suffix"
$AlertName = "high-failure-rate-$Suffix"

$AppInsightsId = az monitor app-insights component show `
  --resource-group $ResourceGroup --app $AppInsights --query id --output tsv

Write-Host "== Action group (email placeholder - edit before real use) =="
az monitor action-group create `
  --resource-group $ResourceGroup --name $ActionGroup --short-name "ai200demo" `
  --action email demo-oncall your-email@example.com `
  --output table

Write-Host "== Log search alert =="
$ActionGroupId = az monitor action-group show -g $ResourceGroup -n $ActionGroup --query id -o tsv
$Query = "requests | where success == false | summarize failedCount = count() by cloud_RoleName | where failedCount > 10"

az monitor scheduled-query create `
  --resource-group $ResourceGroup --name $AlertName `
  --scopes $AppInsightsId `
  --condition "count `"$Query`" > 0" `
  --action-groups $ActionGroupId `
  --evaluation-frequency 5m --window-size 15m --severity 2 `
  --output table
