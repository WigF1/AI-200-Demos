# Slide 30, 33: memory/planner tuning for vector workloads; optional read replica.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

Write-Host "== Planner/memory tuning for vector search =="
az postgres flexible-server parameter set `
  --resource-group $ResourceGroup --server-name $PgServer `
  --name random_page_cost --value "1.1" --output none

az postgres flexible-server parameter set `
  --resource-group $ResourceGroup --server-name $PgServer `
  --name work_mem --value "262144" --output none

Write-Host "== Optional: vertical scale up before adding replicas =="
Write-Host "  az postgres flexible-server update -g $ResourceGroup -n $PgServer --tier MemoryOptimized --sku-name Standard_E2ds_v4"

Write-Host "== Optional: create a read replica =="
Write-Host "  az postgres flexible-server replica create -g $ResourceGroup --replica-name $PgReplica --source-server $PgServer"

Write-ElapsedTime
