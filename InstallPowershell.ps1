
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

winget install Microsoft.PowerShell

Write-Host "PowerShell installed and modules configured!" -ForegroundColor Green
Write-Host "Run InstallMachine.ps1 with the new version of PowerShell to install the rest of the software." -ForegroundColor Green
