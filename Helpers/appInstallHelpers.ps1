function Get-Apps
{
    $configPath = Join-Path $PSScriptRoot "..\config\apps.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Apps config file not found: $configPath"
    }

    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
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
                $installed = Install-AppFromWinget -name $app.name
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

        if (Install-AppFromWinget -name $app.name) {
            $installedApps += $app.name
        }
    }

    return $installedApps
}

function Install-AppFromWinget
{
    param(
        [string]$name = ""
    )

    $listApp = winget list --exact -q $name
    if (![String]::Join("", $listApp).Contains($name)) {
        Write-host "Installing: " $name
        winget install -e -h --accept-source-agreements --accept-package-agreements --id $name 
        return $true
    }
    else {
        Write-host "Skipping: " $name " (already installed)"
    }
    return $false
}
