function Assert-WingetAvailable {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "ERROR: winget is not installed or not available in PATH." -ForegroundColor Red
        Write-Host "winget is required to install apps from config/apps.json where installSource=winget." -ForegroundColor Red
        Write-Host ""
        Write-Host "To install winget, install 'App Installer' from the Microsoft Store:" -ForegroundColor Yellow
        Write-Host "  https://apps.microsoft.com/detail/9nblggh4nns1?hl=en-US&gl=US" -ForegroundColor Yellow
        Write-Host ""
        throw "winget is not available. Install it and re-run this script."
    }

    $wingetVersion = winget --version 2>&1
    Write-Host "winget is available: $wingetVersion"
}

function Confirm-Action {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $answer = Read-Host "$Message [y/N]"
    return $answer -match '^(y|yes)$'
}

function Get-InstallConfig {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $configDir = Join-Path $repoRoot "config"
    $configPath = Join-Path $configDir "config.json"
    $config = $null

    if (Test-Path -LiteralPath $configPath) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        }
        catch {
            throw "Could not read config file at $configPath. Fix JSON format and retry."
        }
    }

    if (-not $config) {
        Write-Host "No config file found at $configPath."
        $gitName = Read-Host "Enter git username (user.name)"
        $gitEmail = Read-Host "Enter git email (user.email)"
        $localInstallerDirsRaw = Read-Host "Enter local installer base directories for installSource=local (optional, comma-separated, e.g. \\NAS1\Installers,\\NAS2\Installers)"
        $localInstallerDirs = @()
        if (-not [string]::IsNullOrWhiteSpace($localInstallerDirsRaw)) {
            $localInstallerDirs = $localInstallerDirsRaw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }

        $config = [PSCustomObject]@{
            GitName = $gitName
            GitEmail = $gitEmail
            LocalInstallerDirs = $localInstallerDirs
        }

        if (-not (Test-Path -LiteralPath $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $config | ConvertTo-Json | Set-Content -LiteralPath $configPath
        Write-Host "Saved config to $configPath"
    }

    if ([string]::IsNullOrWhiteSpace($config.GitName)) {
        $config.GitName = Read-Host "Git username is missing. Enter git username (user.name)"
    }

    if ([string]::IsNullOrWhiteSpace($config.GitEmail)) {
        $config.GitEmail = Read-Host "Git email is missing. Enter git email (user.email)"
    }

    if ($config.PSObject.Properties['LocalInstallerDir'] -and -not $config.PSObject.Properties['LocalInstallerDirs']) {
        $migratedDirs = @()
        if (-not [string]::IsNullOrWhiteSpace($config.LocalInstallerDir)) {
            $migratedDirs = @([string]$config.LocalInstallerDir)
        }
        $config | Add-Member -NotePropertyName LocalInstallerDirs -NotePropertyValue $migratedDirs
        $null = $config.PSObject.Properties.Remove('LocalInstallerDir')
    }

    if (-not $config.PSObject.Properties['LocalInstallerDirs']) {
        $config | Add-Member -NotePropertyName LocalInstallerDirs -NotePropertyValue @()
    }

    $config.LocalInstallerDirs = @([string[]]$config.LocalInstallerDirs | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($config.LocalInstallerDirs.Count -eq 0) {
        Write-Host "No local installer directories configured. You can add them later in config/config.json under LocalInstallerDirs."
    }

    $config | ConvertTo-Json | Set-Content -LiteralPath $configPath
    return $config
}


function Start-NewCurrentShellInstance {
    $shellPath = Get-Process -Id $PID | Select-Object -ExpandProperty Path
    Invoke-Command { & $shellPath } -NoNewScope
}

function Invoke-VsCodeLoginStep {
    if (-not (Confirm-Action -Message "Open VS Code now and login with your GitHub account?")) {
        Write-Host "Skipping VS Code login step."
        return
    }

    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        Write-Warning "The 'code' command is not available. Open VS Code manually and sign in."
        return
    }

    & $codeCommand.Source
    Read-Host "Log into VS Code with your GitHub account and press Enter to continue"
}
