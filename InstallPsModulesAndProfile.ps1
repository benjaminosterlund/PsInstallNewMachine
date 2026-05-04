. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

Install-PsModules

Set-UserPsProfileFromRepo

Write-Host "Modules installed and PS profile configured." -ForegroundColor Green
