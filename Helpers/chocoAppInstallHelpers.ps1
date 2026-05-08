function Assert-ChocoAvailable
{
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Warning "Chocolatey is not installed or not available in PATH."
        Write-Host "To install Chocolatey, run the following in an elevated PowerShell:" -ForegroundColor Yellow
        Write-Host "  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "Chocolatey installs require an elevated (Run as Administrator) shell. Skipping choco apps."
        return $false
    }

    $chocoVersion = choco --version 2>&1
    Write-Host "Chocolatey is available: $chocoVersion"
    return $true
}

function Install-ChocoApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    if (-not (Assert-ChocoAvailable)) { return }
    Get-AppsBySource 'choco' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppFromChoco | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppFromChoco
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {
        $effectiveId = if ($App.PSObject.Properties['chocoId'] -and -not [string]::IsNullOrWhiteSpace($App.chocoId)) { [string]$App.chocoId } else { $App.name }

        Write-Verbose "[choco] Installing '$($App.name)' with id '$effectiveId'"
        Write-Host "Installing: $($App.name)"
        choco install $effectiveId -y
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "choco install failed for '$($App.name)' (exit code $LASTEXITCODE)."
            return
        }
        $App
    }
}
