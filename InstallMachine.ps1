. (Join-Path $PSScriptRoot "Helpers\moduleInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\appInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\onlineAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\localAppInstallHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\psProfileHelpers.ps1")
. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

Assert-WingetAvailable

$myConfig = Get-InstallConfig

$dirDocuments = "$env:USERPROFILE\Documents"
$dirDownloads = "$env:USERPROFILE\Downloads"
$dirRepositories = "$dirDocuments\source\repos"

& (Join-Path $PSScriptRoot "InstallPsModulesAndProfile.ps1")


Install-WingetApps

Install-OnlineApps -DownloadDirectory $dirDownloads

Install-LocalApps


Start-NewCurrentShellInstance

Invoke-VsCodeLoginStep

# Install php with PsPhpInstall
# Not implemented yet


# create Local Repositories
New-Item -ItemType Directory -Path $dirRepositories -Force


#Set git Credentials
git config --global user.name $myConfig.GitName
git config --global user.email $myConfig.GitEmail
git config --global init.defaultBranch main

Write-Host "Done!"