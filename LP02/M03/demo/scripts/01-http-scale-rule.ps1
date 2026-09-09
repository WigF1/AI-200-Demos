# Slide 30: HTTP concurrency scale rule; multiple rules use the highest replica count.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/aca-scale-rules.ps1

# Uses the shared helper (not a plain az containerapp update) so this
# doesn't wipe out 02-keda-servicebus-scaler.ps1's rule if that already
# ran - az containerapp update replaces the entire scale rule set by
# default. See shared/lib/aca-scale-rules.ps1 for why.
Add-OrUpdateScaleRule -App $AcaApp -ResourceGroup $ResourceGroup -RuleName "http-scale-rule" -UpdateArgs @(
    "--min-replicas", "0", "--max-replicas", "10",
    "--scale-rule-name", "http-scale-rule",
    "--scale-rule-type", "http",
    "--scale-rule-http-concurrency", "10"
)

Write-Host "== Confirming all scale rules present =="
az containerapp show --name $AcaApp --resource-group $ResourceGroup --query "properties.template.scale" --output json

Write-ElapsedTime
