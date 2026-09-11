# Slide 5, 7: Standard tier namespace, one queue (point-to-point) and one
# topic + two subscriptions (fan-out).
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Service Bus namespace '$SbNamespace' already exists."
} else {
    Invoke-TimedStep "Service Bus namespace create" {
        az servicebus namespace create `
          --resource-group $ResourceGroup --name $SbNamespace `
          --sku Standard --location $Location --output table
    }
}

Write-Host "== Queue: point-to-point, competing consumers (Slide 7) =="
az servicebus queue show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $QueueName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Queue '$QueueName' already exists."
} else {
    az servicebus queue create `
      --resource-group $ResourceGroup --namespace-name $SbNamespace --name $QueueName `
      --max-delivery-count 5 --enable-dead-lettering-on-message-expiration true `
      --output table
}

Write-Host "== Topic + 2 subscriptions: fan-out (Slide 7, knowledge check Q1) =="
az servicebus topic show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $TopicName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Topic '$TopicName' already exists."
} else {
    az servicebus topic create `
      --resource-group $ResourceGroup --namespace-name $SbNamespace --name $TopicName `
      --output table
}
foreach ($sub in @("notifications", "audit")) {
    az servicebus topic subscription show --resource-group $ResourceGroup --namespace-name $SbNamespace `
      --topic-name $TopicName --name $sub --output none 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subscription '$sub' already exists."
    } else {
        az servicebus topic subscription create `
          --resource-group $ResourceGroup --namespace-name $SbNamespace --topic-name $TopicName `
          --name $sub --output table
    }
}

Write-Host ""
Write-Host "== Connection string for the Python scripts =="
$ConnStr = az servicebus namespace authorization-rule keys list `
  --resource-group $ResourceGroup --namespace-name $SbNamespace `
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv
Write-Host "`$env:SERVICEBUS_CONNECTION_STRING = `"$ConnStr`""
Write-Host "(paste the line above into your shell before running any of the Python demos)"

Write-ElapsedTime
