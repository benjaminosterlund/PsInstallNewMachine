[CmdletBinding()]
param(
    [ValidateSet('winget', 'choco', 'dotnettool', 'online', 'local', 'manual')]
    [string[]]$SkipSources = @(),
    [switch]$Confirm
)

. (Join-Path $PSScriptRoot "Helpers\importHelpers.ps1")

# $ErrorActionPreference = "Stop"

Assert-WingetAvailable

$myConfig = Get-InstallConfig

$dirDownloads = "$env:USERPROFILE\Downloads"

$allSources = @('winget', 'choco', 'dotnettool', 'online', 'local', 'manual')
$sourcesToRun = $allSources | Where-Object { $_ -notin ($SkipSources | ForEach-Object { $_.ToLowerInvariant() }) }

foreach ($source in $sourcesToRun) {
    Install-Apps -InstallSource $source -DownloadDirectory $dirDownloads -Confirm:$Confirm
}


# Install php with PsPhpInstall
# Not implemented yet

Write-Host "App installation complete." -ForegroundColor Green