function Install-ScriptApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    Get-AppsBySource 'script' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppFromScript | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppFromScript
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {
        if (-not $App.PSObject.Properties['installScriptPath'] -or [string]::IsNullOrWhiteSpace($App.installScriptPath)) {
            Write-Warning "Skipping '$($App.name)': no installScriptPath defined."
            return
        }

        $resolvedScriptPath = Resolve-ScriptPath $App.installScriptPath
        if (-not (Test-Path -LiteralPath $resolvedScriptPath -PathType Leaf)) {
            Write-Error "Install script for '$($App.name)' not found at '$resolvedScriptPath'." -Category ObjectNotFound -TargetObject $App
            return
        }

        Write-Verbose "[script] Running install script for '$($App.name)': $resolvedScriptPath"
        Write-Host "Installing (script): $($App.name)"
        try {
            & $resolvedScriptPath -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Install script for '$($App.name)' failed." -Exception $_.Exception -Category OperationStopped -TargetObject $App
            return
        }

        $App
    }
}
