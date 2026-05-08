function Install-LocalApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    Get-AppsBySource 'local' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppFromLocalSource | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppFromLocalSource
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {

    if ([string]::IsNullOrWhiteSpace($App.name) -or [string]::IsNullOrWhiteSpace($App.installerPath)) {
        Write-Warning "Skipping local app entry due to missing name/installerPath."
        return
    }

    $installConfig = Get-InstallConfig
    $localInstallerDirs = @([string[]]$installConfig.LocalInstallerDirs | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($localInstallerDirs.Count -eq 0) {
        Write-Warning "Skipping: $($App.name) (LocalInstallerDirs is missing in config/config.json)"
        return
    }

    $relativeInstallerPath = [string]$App.installerPath
    if ([System.IO.Path]::IsPathRooted($relativeInstallerPath) -or $relativeInstallerPath.StartsWith("\\")) {
        Write-Warning "Skipping: $($App.name) (installerPath must be relative, e.g. 'SomeApp\\setup.exe')"
        return
    }

    $installerFullPath = $null
    foreach ($baseDir in $localInstallerDirs) {
        $candidatePath = Join-Path $baseDir $relativeInstallerPath
        if (Test-Path -LiteralPath $candidatePath) {
            $installerFullPath = $candidatePath
            break
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($App.checkPath) -and (Test-Path -LiteralPath $App.checkPath)) {
        Write-Host "Skipping: $($App.name) (already installed)"
        return
    }

    if ([string]::IsNullOrWhiteSpace($installerFullPath)) {
        Write-Warning "Skipping: $($App.name) (installer not found in configured LocalInstallerDirs for relative path '$relativeInstallerPath')"
        return
    }

    $argumentList = @()
    if ($App.installArgs) {
        $argumentList += [string[]]$App.installArgs
    }

        Write-Verbose "[local] Installing '$($App.name)' from '$installerFullPath'"
        Write-Host "Installing (local): $($App.name)"
        $process = Start-Process -FilePath $installerFullPath -ArgumentList $argumentList -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Warning "Installer for $($App.name) exited with code $($process.ExitCode)."
            return
        }

        $App
    }
}
