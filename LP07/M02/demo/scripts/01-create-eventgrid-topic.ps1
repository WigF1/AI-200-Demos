# Slide 18, 22: custom topic with CloudEvents v1.0 input schema.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az eventgrid topic show --resource-group $ResourceGroup --name $EventGridTopic --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Event Grid topic '$EventGridTopic' already exists."
} else {
    az eventgrid topic create `
      --resource-group $ResourceGroup --name $EventGridTopic --location $Location `
      --input-schema cloudeventschemav1_0 `
      --output table
}

Write-Host "== Filtered event subscription: only StringIn data.status = flagged (Slide 24) =="
$TopicId = az eventgrid topic show -g $ResourceGroup -n $EventGridTopic --query id -o tsv
az eventgrid event-subscription show --name moderation-flagged-sub --source-resource-id $TopicId --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Event subscription 'moderation-flagged-sub' already exists."
} else {
    az eventgrid event-subscription create `
      --name moderation-flagged-sub `
      --source-resource-id $TopicId `
      --endpoint-type webhook `
      --endpoint "https://example.com/webhook-placeholder" `
      --advanced-filter data.status StringIn flagged `
      --output table
    if ($LASTEXITCODE -ne 0) { Write-Host "(replace --endpoint with a real handler URL before running for real)" }
}

Write-Host ""
Write-Host "== Topic endpoint and key for the Python publisher =="
$Endpoint = az eventgrid topic show --resource-group $ResourceGroup --name $EventGridTopic --query endpoint --output tsv
$Key = az eventgrid topic key list --resource-group $ResourceGroup --name $EventGridTopic --query key1 --output tsv
Write-Host "`$env:EVENTGRID_TOPIC_ENDPOINT = `"$Endpoint`""
Write-Host "`$env:EVENTGRID_TOPIC_KEY = `"$Key`""
Write-Host "(paste the two lines above into your shell before running the Python demos)"

Write-ElapsedTime
