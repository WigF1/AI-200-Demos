# Slide 18, 22: custom topic with CloudEvents v1.0 input schema.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp07" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }
$EventGridTopic = "evgt-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az eventgrid topic create `
  --resource-group $ResourceGroup --name $EventGridTopic --location $Location `
  --input-schema cloudeventschemav1_0 `
  --output table

Write-Host "== Filtered event subscription: only StringIn data.status = flagged =="
$TopicId = az eventgrid topic show -g $ResourceGroup -n $EventGridTopic --query id -o tsv
try {
  az eventgrid event-subscription create `
    --name moderation-flagged-sub `
    --source-resource-id $TopicId `
    --endpoint-type webhook `
    --endpoint "https://example.com/webhook-placeholder" `
    --advanced-filter data.status StringIn flagged `
    --output table
} catch {
  Write-Host "(replace --endpoint with a real handler URL before running for real)"
}

Write-Host "== Topic endpoint and key for the Python publisher =="
az eventgrid topic show --resource-group $ResourceGroup --name $EventGridTopic --query endpoint --output tsv
az eventgrid topic key list --resource-group $ResourceGroup --name $EventGridTopic --query key1 --output tsv
