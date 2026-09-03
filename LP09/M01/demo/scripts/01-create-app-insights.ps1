# Slide 9: Log Analytics workspace + workspace-based Application Insights.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp09" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp09-observe" }
$LogAnalyticsWorkspace = "law-$Suffix"
$AppInsights = "appi-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az monitor log-analytics workspace create `
  --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace `
  --output table
$WorkspaceId = az monitor log-analytics workspace show `
  --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --query id --output tsv

az monitor app-insights component create `
  --resource-group $ResourceGroup --app $AppInsights --location $Location `
  --workspace $WorkspaceId `
  --output table

Write-Host "== Connection string for the Python app =="
az monitor app-insights component show `
  --resource-group $ResourceGroup --app $AppInsights `
  --query connectionString --output tsv
