
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

winget install Microsoft.PowerShell

pwsh -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "InstallPsModulesAndProfile.ps1")

Write-Host "PowerShell installed and modules configured!" -ForegroundColor Green
Write-Host "Run InstallMachine.ps1 with the new version of PowerShell to install the rest of the software." -ForegroundColor Green

# Invoke-Command { & "pwsh.exe"  -executionpolicy bypass -File "InstallMachine.ps1"     } # PowerShell 7