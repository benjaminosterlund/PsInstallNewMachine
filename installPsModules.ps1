function Get-PsModules
{
    return @(
        @{name = "PowerHTML" },
        @{name = "PSParseHTML" },
        @{name = "SimplySql" },    
        @{name = "SqlServer" },
        @{name = "PSSharedGoods" },
        @{name = "DockerCompletion" },
        @{name = "Pester" },
        @{name = "PSReadLine" },
        @{name = "7Zip4Powershell" },
        @{name = "PSWritePDF" },
        @{name = "PSWriteWord" }
    );
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