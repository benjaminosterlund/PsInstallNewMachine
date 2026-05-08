function Install-ManualApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    Get-AppsBySource 'manual' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppManually | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppManually
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {
        if (-not [string]::IsNullOrWhiteSpace($App.url)) {
            Write-Host "Opening download page for $($App.name): $($App.url)"
            Start-Process $App.url
        } else {
            Write-Host "No download URL configured for $($App.name)."
        }

        Write-Host ""
        Write-Host "Please install '$($App.name)' manually, then press Enter to continue..." -ForegroundColor Cyan
        Read-Host | Out-Null

        if (-not [string]::IsNullOrWhiteSpace($App.checkPath)) {
            if (Test-Path -LiteralPath $App.checkPath) {
                Write-Host "$($App.name) installed successfully." -ForegroundColor Green
                $App
            } else {
                Write-Warning "$($App.name) does not appear to be installed (checkPath not found)."
            }
            return
        }

        $App
    }
}
