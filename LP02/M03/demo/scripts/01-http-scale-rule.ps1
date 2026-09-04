# Slide 30: HTTP concurrency scale rule; multiple rules use the highest replica count.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

az containerapp update --name $AcaApp --resource-group $ResourceGroup `
  --min-replicas 0 --max-replicas 10 `
  --scale-rule-name http-scale-rule `
  --scale-rule-type http `
  --scale-rule-http-concurrency 10 `
  --output table

az containerapp show --name $AcaApp --resource-group $ResourceGroup --query "properties.template.scale" --output json
