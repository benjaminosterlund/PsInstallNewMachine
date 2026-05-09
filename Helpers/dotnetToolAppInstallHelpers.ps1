$script:DotnetToolListCache = $null

function Assert-DotnetAvailable
{
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Warning ".NET SDK is not installed or not available in PATH."
        Write-Host "Install the .NET SDK from https://dotnet.microsoft.com/download and re-run." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    $dotnetVersion = dotnet --version 2>&1
    Write-Host ".NET SDK is available: $dotnetVersion"
    return $true
}

function Get-DotnetToolListCache
{
    if ($null -ne $script:DotnetToolListCache) { return $script:DotnetToolListCache }

    Write-Verbose "[dotnet] Building installed tool cache..."
    $script:DotnetToolListCache = @{}

    dotnet tool list -g 2>$null |
        Select-Object -Skip 2 |
        ForEach-Object {
            $parts = $_ -split '\s+'
            if ($parts.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($parts[0])) {
                $script:DotnetToolListCache[$parts[0].ToLowerInvariant()] = $true
            }
        }

    $script:DotnetToolListCache
}

function Test-DotnetToolInstalled
{
    param(
        [Parameter(Mandatory)]
        [object]$App
    )

    $effectiveId = Get-DotnetToolId $App
    $cache = Get-DotnetToolListCache
    return $cache.ContainsKey($effectiveId.ToLowerInvariant())
}

function Get-DotnetToolId
{
    param(
        [Parameter(Mandatory)]
        [object]$App
    )

    if ($App.PSObject.Properties['dotnetToolId'] -and -not [string]::IsNullOrWhiteSpace($App.dotnetToolId)) {
        return [string]$App.dotnetToolId
    }
    return $App.name
}

function Install-DotnetToolApps
{
    [CmdletBinding()]
    param(
        [switch]$Confirm
    )

    if (-not (Assert-DotnetAvailable)) { return }

    Get-AppsBySource 'dotnettool' |
        ForEach-Object { Install-AppFromDotnetTool $_ }
}

function Install-AppFromDotnetTool
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {
        $toolId = Get-DotnetToolId $App

        Write-Verbose "[dotnet] Installing/updating '$($App.name)' with tool id '$toolId'"
        Write-Host "Installing: $($App.name)"

        dotnet tool update --global $toolId | Out-Host

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "dotnet tool update failed for '$($App.name)' using id '$toolId' (exit code $LASTEXITCODE)."
        }
    }
}
