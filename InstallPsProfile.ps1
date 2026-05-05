. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")


Set-PsProfile

Write-Host "PS profile configured." -ForegroundColor Green
