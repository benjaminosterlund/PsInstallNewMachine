param(
    [switch]$SkipWingetApps,
    [switch]$SkipOnlineApps,
    [switch]$SkipLocalApps,
    [switch]$SkipVsCodeLogin
)

. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\appInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\onlineAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\localAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

$myConfig = Get-InstallConfig

$dirDownloads = "$env:USERPROFILE\Downloads"

if (-not $SkipWingetApps) {
    Install-WingetApps
}

if (-not $SkipOnlineApps) {
    Install-OnlineApps -DownloadDirectory $dirDownloads
}

if (-not $SkipLocalApps) {
    Install-LocalApps
}


# Install php with PsPhpInstall
# Not implemented yet

Write-Host "App installation complete." -ForegroundColor Green