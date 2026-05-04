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

    Foreach ($module in $psGalleryModules) {
        if(Install-PsModule -name $module.name){
            $installedModules += $module.name
        }
    }

    return $installedModules
}


function Install-PsModule
{
    param(
        [string]$name = ""
    )

    if (-not (Get-Module -ErrorAction Ignore -ListAvailable $name)) {
        Write-Verbose "Installing $name module for the current user..."
        Install-Module -Scope CurrentUser $name -ErrorAction Stop
        return $true
    }else{
        Write-Verbose "$name module is already installed."
    }
    return $false
}