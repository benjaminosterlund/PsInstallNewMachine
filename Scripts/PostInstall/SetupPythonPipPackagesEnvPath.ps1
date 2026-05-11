function Get-UserEnvPath {
    [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Set-UserEnvPath {
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    [Environment]::SetEnvironmentVariable('Path', $Value, 'User')
}

function Add-PathEntry {
    param(
        [string] $PathValue,

        [Parameter(Mandatory)]
        [string] $Entry
    )

    $parts = $PathValue -split ';' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($parts -contains $Entry) {
        return ($parts -join ';')
    }

    return (($parts + $Entry) -join ';')
}

function Setup-PythonPipPackagesEnvPath {
    $pythonScripts = Join-Path $env:APPDATA 'Python\Python314\Scripts'

    if (-not (Test-Path -LiteralPath $pythonScripts)) {
        Write-Warning "Python scripts directory not found at '$pythonScripts'. Skipping."
        return
    }

    $userPath = Get-UserEnvPath
    $newPath = Add-PathEntry -PathValue $userPath -Entry $pythonScripts

    if ($newPath -eq $userPath) {
        Write-Host "'$pythonScripts' is already in user PATH."
        return
    }

    Set-UserEnvPath -Value $newPath
    Write-Host "Added '$pythonScripts' to user PATH."
}

Setup-PythonPipPackagesEnvPath