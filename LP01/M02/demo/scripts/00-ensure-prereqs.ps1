# Makes this module runnable on its own, without LP01/M01 having run
# first. Mirrors what M01's 01-create-acr.ps1 and 02-build-push-acr-task.ps1
# do, but each step first checks whether the resource already exists so
# that running this after M01 (the normal path) is a fast no-op, while
# running it cold still gets you a working ACR + pushed image.
#
# Dot-sourced automatically by every other script in this module - you
# don't need to run it directly, though it's safe to.

Write-Host "== Ensuring prerequisites for LP01/M02 (resource group, ACR, ${ImageName}:${ImageTag}) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    Write-Host "Creating resource group '$ResourceGroup'..."
    az group create --name $ResourceGroup --location $Location --output table
}

az acr show --name $AcrName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ACR '$AcrName' already exists."
} else {
    Write-Host "Creating ACR '$AcrName' (not found - LP01/M01 likely hasn't run)..."
    az acr create --resource-group $ResourceGroup --name $AcrName `
      --sku Standard --admin-enabled false --output table
}

az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Image '${ImageName}:${ImageTag}' already in '$AcrName'."
} else {
    Write-Host "Building and pushing '${ImageName}:${ImageTag}' (not found - LP01/M01 likely hasn't run)..."
    az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" `
      --file "$AppDir/Dockerfile" $AppDir --output none
}

Write-Host "Prerequisites ready."
