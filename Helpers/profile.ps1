function Install-ModuleIfNotAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Install-Module -Name $Name -Scope CurrentUser
    }
}


Install-ModuleIfNotAvailable -Name PSReadLine
if (-not (Get-Module PSReadLine)) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
}


Install-ModuleIfNotAvailable -Name psgitcompletions
Import-Module psgitcompletions

Install-ModuleIfNotAvailable -Name DockerCompletion
Import-Module DockerCompletion

Install-ModuleIfNotAvailable -Name Pester
Import-Module Pester

Install-ModuleIfNotAvailable -Name SimplySql
Import-Module SimplySql





### Unblock-File $PSScriptRoot"\Modules\PsPhpInstall\PsPhpInstall.psm1"
# Import-Module PsPhpInstall

# choco upgrade chocolatey

# Import-Module PsPhpInstall



Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

if ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    try {
        Set-PSReadLineOption -ShowToolTips -PredictionViewStyle ListView
    }
    catch {
    }
}



# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser



### Import all modules....

# $path = Get-Item (Get-Module -ListAvailable).Path
# $fullpath = (Get-ChildItem ($path.PsParentPath) | Where {$_.Name -Like "*.psm1"}).FullName 

# foreach ($item in $fullpath)
# {
#     Import-Module $item | Out-Null
# }