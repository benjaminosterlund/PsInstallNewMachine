#choco upgrade chocolatey
#choco upgrade pwsh

Import-Module psgitcompletions
Import-Module DockerCompletion
Import-Module PSReadLine
Import-Module Pester
Import-Module SimplySql

# Import-Module PsPhpInstall


Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineOption -ShowToolTips -PredictionViewStyle:ListView



Write-Output "Modules loaded from C:\Users\oster\Documents\PowerShell\Modules" 

