function Install-OnlineApps
{
    [CmdletBinding()]
    param(
        [string]$DownloadDirectory = (Join-Path $env:TEMP "PsInstallNewMachine"),
        [switch]$Confirm
    )

    Get-AppsBySource 'online' | Where-AppShouldInstall -Confirm:$Confirm | Install-AppFromOnlineSource -DownloadDirectory $DownloadDirectory | Invoke-AppPostInstallAction | Out-Null
}

function Install-AppFromOnlineSource
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App,

        [Parameter(Mandatory)]
        [string]$DownloadDirectory
    )

    process {
        Write-Verbose "[online] Determining install strategy for '$($App.name)'"

        if ($App.PSObject.Properties['url'] -and -not [string]::IsNullOrWhiteSpace($App.url)) {
            $fileName = $App.fileName
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = [System.IO.Path]::GetFileName(([Uri]$App.url).AbsolutePath)
            }
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = "$($App.name).exe"
            }
            $installerPath = Join-Path $DownloadDirectory $fileName

            Write-Verbose "[online] Downloading '$($App.name)' from '$($App.url)'"
            Write-Host "Downloading: $($App.name)"
            Invoke-WebRequest -Uri $App.url -OutFile $installerPath

            $argumentList = @()
            if ($App.installArgs) { $argumentList += [string[]]$App.installArgs }

            Write-Host "Installing: $($App.name)"
            $process = Start-Process -FilePath $installerPath -ArgumentList $argumentList -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                Write-Error "Installer for '$($App.name)' exited with code $($process.ExitCode)."
                return
            }
            $App
            return
        }

        Write-Warning "No install strategy found for '$($App.name)' (needs 'url' or 'installScriptPath')."
    }
}

function Resolve-ScriptPath {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string]$BasePath = (Split-Path $PSScriptRoot -Parent)
    )

    if ([System.IO.Path]::IsPathRooted($ScriptPath)) {
        return $ScriptPath
    }

    return (Join-Path $BasePath $ScriptPath)
}