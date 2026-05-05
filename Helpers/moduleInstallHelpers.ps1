function Get-PsModules
{
    $configPath = Join-Path $PSScriptRoot "..\config\modules.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Modules config file not found: $configPath"
    }

    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

function Install-PsModules
{
    $installedModules = @()
    $psGalleryModules = Get-PsModules

    foreach ($module in $psGalleryModules) {
        $name = $module.name
        $prefix = $null
        if ($module.PSObject.Properties["prefix"]) {
            $prefix = $module.prefix
        }
        if (Install-PsModule -name $name -prefix $prefix) {
            $installedModules += $name
        }
    }

    return $installedModules
}


function Install-PsModule
{
    param(
        [string]$name = "",
        [string]$prefix = $null
    )

    if (-not (Get-Module -ErrorAction Ignore -ListAvailable $name)) {
        Write-Host "`n`nInstalling $name module for the current user..." -ForegroundColor Cyan
        Install-Module -Scope CurrentUser -Name $name -AllowClobber -ErrorAction Stop
        if ($prefix) {
            Write-Host "Module $name should be imported with prefix $prefix to avoid naming conflicts." -ForegroundColor Yellow
        }
        return $true
    } else {
        Write-Host "$name module is already installed." -ForegroundColor Yellow
    }
    return $false
}