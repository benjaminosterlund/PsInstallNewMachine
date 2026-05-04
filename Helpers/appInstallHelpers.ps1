function Get-Apps
{
    $configPath = Join-Path $PSScriptRoot "..\config\apps.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Apps config file not found: $configPath"
    }

    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

function Invoke-AppPostInstallAction
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$App,

        [Parameter(Mandatory = $true)]
        [bool]$WasInstalled
    )

    if (-not $App.PSObject.Properties['postInstall']) {
        return
    }

    $postInstall = $App.postInstall
    if (-not $postInstall) {
        return
    }

    $runWhen = "installed"
    if ($postInstall.PSObject.Properties['runWhen'] -and -not [string]::IsNullOrWhiteSpace($postInstall.runWhen)) {
        $runWhen = [string]$postInstall.runWhen
    }

    if ($runWhen -ieq "installed" -and -not $WasInstalled) {
        return
    }

    if (-not $postInstall.PSObject.Properties['scriptPath'] -or [string]::IsNullOrWhiteSpace($postInstall.scriptPath)) {
        Write-Warning "Skipping post-install for $($App.name): scriptPath is missing."
        return
    }

    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $scriptPath = [string]$postInstall.scriptPath
    $resolvedScriptPath = if ([System.IO.Path]::IsPathRooted($scriptPath)) {
        $scriptPath
    }
    else {
        Join-Path $repoRoot $scriptPath
    }

    if (-not (Test-Path -LiteralPath $resolvedScriptPath)) {
        Write-Warning "Skipping post-install for $($App.name): script not found at '$resolvedScriptPath'."
        return
    }

    $promptMessage = "Run post-install script for '$($App.name)'?"
    if ($postInstall.PSObject.Properties['promptMessage'] -and -not [string]::IsNullOrWhiteSpace($postInstall.promptMessage)) {
        $promptMessage = [string]$postInstall.promptMessage
    }

    if (-not (Confirm-Action -Message $promptMessage)) {
        Write-Host "Skipping post-install for $($App.name)."
        return
    }

    $argumentList = @()
    if ($postInstall.PSObject.Properties['args'] -and $postInstall.args) {
        $argumentList += [string[]]$postInstall.args
    }

    $continueOnError = $false
    if ($postInstall.PSObject.Properties['continueOnError']) {
        $continueOnError = [bool]$postInstall.continueOnError
    }

    try {
        & $resolvedScriptPath @argumentList
        Write-Host "Post-install finished for $($App.name)."
    }
    catch {
        if ($continueOnError) {
            Write-Warning "Post-install failed for $($App.name): $($_.Exception.Message)"
        }
        else {
            throw
        }
    }
}

function Install-Apps
{
    param(
        [string[]]$InstallSources = @(),
        [string]$DownloadDirectory = (Join-Path $env:TEMP "PsInstallNewMachine")
    )

    $installedApps = @()
    $apps = Get-Apps

    if ($InstallSources.Count -gt 0) {
        $sourceFilter = $InstallSources | ForEach-Object { $_.ToLowerInvariant() }
        $apps = $apps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.installSource) -and $sourceFilter -contains $_.installSource.ToLowerInvariant()
        }
    }

    foreach ($app in $apps) {
        if ([string]::IsNullOrWhiteSpace($app.name) -or [string]::IsNullOrWhiteSpace($app.installSource)) {
            Write-Warning "Skipping app entry due to missing name/installSource."
            continue
        }

        $source = $app.installSource.ToLowerInvariant()
        $installed = $false

        switch ($source) {
            "winget" {
                $wingetId = $null
                if ($app.PSObject.Properties['wingetId'] -and -not [string]::IsNullOrWhiteSpace($app.wingetId)) {
                    $wingetId = [string]$app.wingetId
                }

                $installed = Install-AppFromWinget -name $app.name -id $wingetId
            }
            "online" {
                $installed = Install-AppFromOnlineSource -App $app -DownloadDirectory $DownloadDirectory
            }
            "local" {
                $installed = Install-AppFromLocalSource -App $app
            }
            default {
                Write-Warning "Skipping $($app.name): unsupported installSource '$($app.installSource)'."
            }
        }

        if ($installed) {
            $installedApps += $app.name
        }

        Invoke-AppPostInstallAction -App $app -WasInstalled:$installed
    }

    return $installedApps
}

function Install-WingetApps
{
    $installedApps = @()
    $wingetApps = @(Get-Apps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.installSource) -and $_.installSource.ToLowerInvariant() -eq "winget"
        })

    foreach ($app in $wingetApps) {
        if ([string]::IsNullOrWhiteSpace($app.name)) {
            Write-Warning "Skipping winget app entry due to missing name."
            continue
        }

        if (-not (Confirm-Action -Message "Install winget app '$($app.name)'?")) {
            Write-Host "Skipping winget app: $($app.name)"
            continue
        }

        $wingetId = $null
        if ($app.PSObject.Properties['wingetId'] -and -not [string]::IsNullOrWhiteSpace($app.wingetId)) {
            $wingetId = [string]$app.wingetId
        }

        $installed = Install-AppFromWinget -name $app.name -id $wingetId
        if ($installed) {
            $installedApps += $app.name
        }

        Invoke-AppPostInstallAction -App $app -WasInstalled:$installed
    }

    return $installedApps
}

function Install-AppFromWinget
{
    param(
        [string]$name = "",
        [string]$id = ""
    )

    $effectiveId = if (-not [string]::IsNullOrWhiteSpace($id)) { $id } else { $name }
    $displayName = if (-not [string]::IsNullOrWhiteSpace($name)) { $name } else { $effectiveId }

    $listApp = winget list --id $effectiveId --exact 2>$null
    if (![String]::Join("", $listApp).Contains($effectiveId)) {
        Write-host "Installing: " $displayName
        winget install -e -h --accept-source-agreements --accept-package-agreements --id $effectiveId
        return $true
    }
    else {
        Write-host "Skipping: " $displayName " (already installed)"
    }
    return $false
}
