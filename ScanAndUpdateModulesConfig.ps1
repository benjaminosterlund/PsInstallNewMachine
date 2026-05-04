. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")

$modulesConfigPath = Join-Path $PSScriptRoot "config\modules.json"

if (-not (Test-Path -LiteralPath $modulesConfigPath)) {
    throw "Modules config file not found: $modulesConfigPath"
}

$modules = @(Get-Content -LiteralPath $modulesConfigPath -Raw | ConvertFrom-Json)
if (-not $modules) {
    $modules = @()
}

$existingModuleNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($module in $modules) {
    if (-not [string]::IsNullOrWhiteSpace($module.name)) {
        [void]$existingModuleNames.Add([string]$module.name)
    }
}

$candidateModuleNames = @()
$installedModuleCommand = Get-Command Get-InstalledModule -ErrorAction SilentlyContinue

if ($installedModuleCommand) {
    $candidateModuleNames = @(
        Get-InstalledModule -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name -Unique |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object
    )
}
else {
    $candidateModuleNames = @(
        Get-Module -ListAvailable |
        Select-Object -ExpandProperty Name -Unique |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object
    )
}

$didChange = $false

foreach ($moduleName in $candidateModuleNames) {
    if ($existingModuleNames.Contains($moduleName)) {
        continue
    }

    if (Confirm-Action -Message "Add module '$moduleName' to config/modules.json?") {
        $modules += [PSCustomObject]@{
            name = $moduleName
        }
        [void]$existingModuleNames.Add($moduleName)
        $didChange = $true
        Write-Host "Added module: $moduleName"
    }
}

if ($didChange) {
    $modules | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $modulesConfigPath
    Write-Host "Saved updates to $modulesConfigPath"
}
else {
    Write-Host "No module updates were added."
}
