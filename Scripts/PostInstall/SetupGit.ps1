. (Join-Path $PSScriptRoot "..\..\Helpers\helpers.ps1")

$myConfig = Get-InstallConfig
$dirRepositories = Join-Path $env:USERPROFILE "Documents\source\repos"

New-Item -ItemType Directory -Path $dirRepositories -Force | Out-Null

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    Write-Warning "git command not found. Skipping git configuration."
    return
}

git config --global user.name $myConfig.GitName
git config --global user.email $myConfig.GitEmail
git config --global init.defaultBranch main

Write-Host "Git setup complete."
