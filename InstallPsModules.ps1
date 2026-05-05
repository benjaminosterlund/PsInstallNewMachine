. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Install-PsModules

Write-Host "Modules installed" -ForegroundColor Green
