function Install-OnlineApps
{
    param(
        [string]$DownloadDirectory = (Join-Path $env:TEMP "PsInstallNewMachine")
    )

    $installedApps = @()
    $onlineApps = @(Get-Apps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.installSource) -and $_.installSource.ToLowerInvariant() -eq "online"
        })

    foreach ($app in $onlineApps) {
        if ([string]::IsNullOrWhiteSpace($app.name)) {
            Write-Warning "Skipping online app entry due to missing name."
            continue
        }

        if (-not (Confirm-Action -Message "Install online app '$($app.name)'?")) {
            Write-Host "Skipping online app: $($app.name)"
            continue
        }

        $installed = Install-AppFromOnlineSource -App $app -DownloadDirectory $DownloadDirectory
        if ($installed) {
            $installedApps += $app.name
        }

        Invoke-AppPostInstallAction -App $app -WasInstalled:$installed
    }

    return $installedApps
}

function Install-AppFromOnlineSource
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$App,

        [Parameter(Mandatory = $true)]
        [string]$DownloadDirectory
    )

    if ([string]::IsNullOrWhiteSpace($App.name) -or [string]::IsNullOrWhiteSpace($App.url)) {
        Write-Warning "Skipping online app entry due to missing name/url."
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($App.checkPath) -and (Test-Path -LiteralPath $App.checkPath)) {
        Write-Host "Skipping: $($App.name) (already installed)"
        return $false
    }

    $fileName = $App.fileName
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        $fileName = [System.IO.Path]::GetFileName(([Uri]$App.url).AbsolutePath)
    }
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        $fileName = "$($App.name).exe"
    }

    $installerPath = Join-Path $DownloadDirectory $fileName

    Write-Host "Downloading: $($App.name)"
    Invoke-WebRequest -Uri $App.url -OutFile $installerPath

    $argumentList = @()
    if ($App.installArgs) {
        $argumentList += [string[]]$App.installArgs
    }

    Write-Host "Installing: $($App.name)"
    $process = Start-Process -FilePath $installerPath -ArgumentList $argumentList -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        return $true
    }

    Write-Warning "Installer for $($App.name) exited with code $($process.ExitCode)."
    return $false
}
