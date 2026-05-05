. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\appInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\onlineAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\localAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

$null = Get-InstallConfig

$dirDownloads = "$env:USERPROFILE\Downloads"

Install-WingetApps

Install-OnlineApps -DownloadDirectory $dirDownloads

Install-LocalApps

Start-NewCurrentShellInstance

Invoke-VsCodeLoginStep

# Install php with PsPhpInstall
# Not implemented yet

Write-Host "Done!"