function Install-LocalApps
{
    $installedApps = @()
    $localApps = @(Get-Apps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.installSource) -and $_.installSource.ToLowerInvariant() -eq "local"
        })

    foreach ($app in $localApps) {
        if ([string]::IsNullOrWhiteSpace($app.name)) {
            Write-Warning "Skipping local app entry due to missing name."
            continue
        }

        if (-not (Confirm-Action -Message "Install local app '$($app.name)'?")) {
            Write-Host "Skipping local app: $($app.name)"
            continue
        }

        $installed = Install-AppFromLocalSource -App $app
        if ($installed) {
            $installedApps += $app.name
        }

        Invoke-AppPostInstallAction -App $app -WasInstalled:$installed
    }

    return $installedApps
}

function Install-AppFromLocalSource
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$App
    )

    if ([string]::IsNullOrWhiteSpace($App.name) -or [string]::IsNullOrWhiteSpace($App.installerPath)) {
        Write-Warning "Skipping local app entry due to missing name/installerPath."
        return $false
    }

    $installConfig = Get-InstallConfig
    $localInstallerDirs = @([string[]]$installConfig.LocalInstallerDirs | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($localInstallerDirs.Count -eq 0) {
        Write-Warning "Skipping: $($App.name) (LocalInstallerDirs is missing in config/config.json)"
        return $false
    }

    $relativeInstallerPath = [string]$App.installerPath
    if ([System.IO.Path]::IsPathRooted($relativeInstallerPath) -or $relativeInstallerPath.StartsWith("\\")) {
        Write-Warning "Skipping: $($App.name) (installerPath must be relative, e.g. 'SomeApp\\setup.exe')"
        return $false
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
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($installerFullPath)) {
        Write-Warning "Skipping: $($App.name) (installer not found in configured LocalInstallerDirs for relative path '$relativeInstallerPath')"
        return $false
    }

    $argumentList = @()
    if ($App.installArgs) {
        $argumentList += [string[]]$App.installArgs
    }

    Write-Host "Installing (local): $($App.name)"
    $process = Start-Process -FilePath $installerFullPath -ArgumentList $argumentList -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        return $true
    }

    Write-Warning "Installer for $($App.name) exited with code $($process.ExitCode)."
    return $false
}
