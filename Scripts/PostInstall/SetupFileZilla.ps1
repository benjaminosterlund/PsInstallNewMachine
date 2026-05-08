. (Join-Path $PSScriptRoot "..\..\Helpers\helpers.ps1")

$myConfig = Get-InstallConfig

$sourcePath = $myConfig.FileZillaSiteManagerSource
if ([string]::IsNullOrWhiteSpace($sourcePath)) {
    Write-Warning "FileZillaSiteManagerSource is not configured in config/config.json. Skipping."
    return
}

$sourcePath = [Environment]::ExpandEnvironmentVariables($sourcePath.Trim().Trim('"'))

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Warning "FileZilla sitemanager.xml source not found at '$sourcePath'. Skipping."
    return
}


$destDir  = Join-Path $env:APPDATA "FileZilla" # e.g. C:\Users\[user]\AppData\Roaming\FileZilla
$destPath = Join-Path $destDir "sitemanager.xml"

if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

if (Test-Path -LiteralPath $destPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "$destPath.$timestamp.bak"
    Copy-Item -LiteralPath $destPath -Destination $backup -Force
    Write-Host "Backed up existing sitemanager.xml to '$backup'"
}

Copy-Item -LiteralPath $sourcePath -Destination $destPath -Force
Write-Host "FileZilla sitemanager.xml copied from '$sourcePath' to '$destPath'"
