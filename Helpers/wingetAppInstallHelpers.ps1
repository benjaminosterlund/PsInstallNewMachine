function Install-WingetApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    Get-AppsBySource 'winget' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppFromWinget | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppFromWinget
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {
        $effectiveId = if ($App.PSObject.Properties['wingetId'] -and -not [string]::IsNullOrWhiteSpace($App.wingetId)) { [string]$App.wingetId } else { $App.name }


        # OLD
        # Write-Verbose "[winget] Installing '$($App.name)' with id '$effectiveId'"
        # Write-Host "Installing: $($App.name)"
        # winget install -e -h --accept-source-agreements --accept-package-agreements --id $effectiveId | Out-Null



#new - improved error handling
        Write-Verbose "[winget] Installing '$($App.name)' with id '$effectiveId'"
        Write-Host "Installing: $($App.name)"

        $wingetArgs = @(
            'install'
            '-e'
            '-h'
            '--accept-source-agreements'
            '--accept-package-agreements'
            '--id', $effectiveId
        )

        if ($App.PSObject.Properties['wingetArgs'] -and $App.wingetArgs.Count -gt 0) {
            $wingetArgs += [string[]]$App.wingetArgs
        }

        if ($App.PSObject.Properties['installArgs'] -and $App.installArgs.Count -gt 0) {
            $wingetArgs += '--override', ([string[]]$App.installArgs -join ' ')
        }

        & winget @wingetArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Error `
                -Message "winget failed to install '$($App.Name)' using id '$effectiveId'. Exit code: $LASTEXITCODE" `
                -Category NotInstalled `
                -TargetObject $App

            return
        }



        $App
    }
}
