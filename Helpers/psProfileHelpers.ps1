function Add-ProfileContentIfNotExists {
    param(
        [string]$Content,
        [switch]$NewLineBefore,
        [switch]$NewLineAfter
    )

    if (-not (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts)) {
        New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force | Out-Null
    }

    $normalizedContent = $Content -replace '\r\n', "\n" -replace '\r', "\n"

    if ($normalizedContent -notmatch "\S") {
        return # Don't add empty or whitespace-only content
    }

    $profileContentRaw = [string](Get-Content $PROFILE.CurrentUserAllHosts -Raw)
    $normalizedProfile = $profileContentRaw -replace '\r\n', "\n" -replace '\r', "\n"
    $isNewContent = $normalizedProfile.ToLower().IndexOf($normalizedContent.ToLower()) -eq -1
    if ($isNewContent) {
        if ($NewLineBefore) {
            $Content = "`n" + $Content
        }
        if ($NewLineAfter) {
            $Content = $Content + "`n"
        }
        Add-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value $Content
    }
}


function Set-PsProfile{

    $psGalleryModules = Get-PsModules


    if(-not (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts)) {
        New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force | Out-Null
    }


    $importPsReadLineContent = @"
if (-not (Get-Module PSReadLine)) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
}
"@
    Add-ProfileContentIfNotExists -Content $importPsReadLineContent -NewLineAfter


    foreach ($module in $psGalleryModules) {
        $name = $module.name
        $prefix = $null
        $import = $false
        if ($module.PSObject.Properties["prefix"]) {
            $prefix = $module.prefix
        }
        if ($module.PSObject.Properties["import"]) {
            $import = $module.import
        }

        if (-not (Get-Module -ErrorAction Ignore -ListAvailable $name)) {
            continue
        }

        if($prefix){
            $importStatement = "Import-Module $name -Prefix $prefix"
        }else{
            $importStatement = "Import-Module $name"
        }

        if(-not $import){
             $importStatement = "#" + $importStatement
        }

        Add-ProfileContentIfNotExists -Content $importStatement

    }


    # --- MyPsTools module is for custom PowerShell tools ---
    New-MyPsToolsModuleScaffold
    Add-ProfileContentIfNotExists -Content "Import-Module MyPsTools" -NewLineBefore -NewLineAfter

    $psReadLineConfig = @'
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

if ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    try {
        Set-PSReadLineOption -ShowToolTips -PredictionViewStyle ListView
    }
    catch {
    }
}
'@

    Add-ProfileContentIfNotExists -Content $psReadLineConfig -NewLineBefore -NewLineAfter


    Add-ProfileContentIfNotExists -Content "# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -NewLineBefore -NewLineAfter

}

function New-MyPsToolsModuleScaffold{
    param(
        [switch]$Force
    )
    $moduleBase = ($env:PSModulePath -split [IO.Path]::PathSeparator)[0]
    $moduleName = "MyPsTools"
    $modulePath = Join-Path $moduleBase $moduleName

    if ((Test-Path -LiteralPath $modulePath)) {
        if (-not $Force) {
            Write-Host "MyPsTools already exists. Use -Force to recreate." -ForegroundColor Yellow
            return
        }

        Remove-Item $modulePath -Recurse -Force 
    }

    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    
    New-Item -ItemType File -Path (Join-Path $modulePath "$moduleName.psm1") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $modulePath "Public") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $modulePath "Private") -Force | Out-Null


    $psm1Content = @'
# Load private functions
Get-ChildItem "$PSScriptRoot\Private\*.ps1" | ForEach-Object {
    . $_.FullName
}

# Load public functions
$publicFiles = Get-ChildItem "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue

foreach ($file in $publicFiles) {
    . $file.FullName
}

# Export only functions named like the public file
Export-ModuleMember -Function ($publicFiles | ForEach-Object { $_.BaseName })
'@

        Set-Content -Path (Join-Path $modulePath "$moduleName.psm1") -Value $psm1Content -Encoding UTF8



                # --- Create example private function ---
        $privateFunction = @'
function Get-InternalMessage {
    "Secret internal logic"
}
'@

        Set-Content -Path (Join-Path $modulePath "Private\Get-InternalMessage.ps1") -Value $privateFunction -Encoding UTF8





        # --- Create public functions ---
        $publicProfileGreeting = @'
function Invoke-ProfileGreeting {
    [CmdletBinding()]
    param()

    Write-Host "In a galaxy far, far away..." -ForegroundColor Yellow
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Invoke-ProfileGreeting.ps1") -Value $publicProfileGreeting -Encoding UTF8


        $publicWriteType = @'
function Write-Type {
    param([string]$Text, [int]$Delay = 15)

    foreach ($c in $Text.ToCharArray()) {
        Write-Host -NoNewline $c -ForegroundColor Yellow
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Write-Type.ps1") -Value $publicWriteType -Encoding UTF8




        $publicInvokeTextToSpeech = @'
function Invoke-TextToSpeech {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text
    )

    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

    # Register Ctrl+C / session exit handler
    $event = Register-EngineEvent PowerShell.Exiting -Action {
        $synth.SpeakAsyncCancelAll()
    }

    try {
        $async = $synth.SpeakAsync($Text)

        # Wait until speech finishes or is cancelled
        while ($async.IsCompleted -eq $false) {
            Start-Sleep -Milliseconds 100
        }
    }
    finally {
        # Cleanup
        Unregister-Event -SourceIdentifier $event.Name -ErrorAction SilentlyContinue
        $synth.Dispose()
    }
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Invoke-TextToSpeech.ps1") -Value $publicInvokeTextToSpeech -Encoding UTF8







        $publicGetModuleStatus = @'
function Get-ModuleStatus {
    param(
        [switch]$All
    )

    $userModulePaths = @(
        Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules'
        Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules'
    ).ForEach({ $_.ToLowerInvariant() })

    $importedModules = Get-Module | Select-Object -ExpandProperty Name

    Get-Module -ListAvailable |
        Sort-Object Name, Version -Descending |
        Group-Object Name |
        ForEach-Object { $_.Group[0] } |
        ForEach-Object {
            $moduleBase = $_.ModuleBase.ToLowerInvariant()
            $isUser = $userModulePaths | Where-Object {
                $moduleBase.StartsWith($_)
            }

            [PSCustomObject]@{
                Name       = $_.Name
                Version    = $_.Version
                Imported   = $importedModules -contains $_.Name
                UserModule = [bool]$isUser
                Path       = $_.ModuleBase
            }
        } |
        Where-Object { $All -or $_.UserModule } |
        Sort-Object Name
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Get-ModuleStatus.ps1") -Value $publicGetModuleStatus -Encoding UTF8





        $publicShowModuleStatus = @'
function Show-ModuleStatus {
    param(
        [switch]$All
    )

    Get-ModuleStatus -All:$All |
        Format-Table Name, Version, Imported, UserModule, Path -AutoSize
}

'@

    Set-Content -Path (Join-Path $modulePath "Public\Show-ModuleStatus.ps1") -Value $publicShowModuleStatus -Encoding UTF8






        $publicImportModuleFromMenu = @'
function Import-ModuleFromMenu {
    param(
        [switch]$All,
        [switch]$IncludeImported
    )

    $modules = Get-ModuleStatus -All:$All |
        Where-Object { $IncludeImported -or -not $_.Imported }

    if (-not $modules) {
        Write-Host "No modules available to import."
        return
    }

    $selected = Show-Menu `
        -MenuItems $modules `
        -MultiSelect `
        -MenuItemFormatter {
            param($m)

            $status = if ($m.Imported) { "imported" } else { "not imported" }
            "{0} {1} [{2}]" -f $m.Name, $m.Version, $status
        }

    if (-not $selected) {
        return
    }

    foreach ($module in $selected) {
        Import-Module $module.Name -Verbose
    }
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Import-ModuleFromMenu.ps1") -Value $publicImportModuleFromMenu -Encoding UTF8






        $publicShowModuleCommandsFromMenu = @'
function Show-ModuleCommandsFromMenu {
    param(
        [switch]$All,
        [switch]$IncludeImportedOnly
    )

    $modules = Get-ModuleStatus -All:$All

    if ($IncludeImportedOnly) {
        $modules = $modules | Where-Object Imported
    }

    if (-not $modules) {
        Write-Host "No modules found."
        return
    }

    $selected = Show-Menu `
        -MenuItems $modules `
        -MenuItemFormatter {
            param($m)

            $status = if ($m.Imported) { "imported" } else { "not imported" }
            "{0} {1} [{2}]" -f $m.Name, $m.Version, $status
        }

    if (-not $selected) {
        return
    }

    # foreach ($module in @($selected)) {
    #     Write-Host ""
    #     Write-Host $module.Name -ForegroundColor Cyan
    #     Write-Host ("-" * $module.Name.Length) -ForegroundColor Cyan

    #     Get-Command -Module $module.Name -ErrorAction SilentlyContinue |
    #         Sort-Object CommandType, Name |
    #         Format-Table CommandType, Name, Version -AutoSize
    # }

    foreach ($module in @($selected)) {
        Write-Host ""
        Write-Host $module.Name -ForegroundColor Cyan
        Write-Host ("-" * $module.Name.Length) -ForegroundColor Cyan
        Write-Host "Path: $($module.Path)" -ForegroundColor DarkGray

        $loadedModule = Get-Module -Name $module.Name | Select-Object -First 1

        if (-not $loadedModule) {
            $choice = Show-Menu `
                -MenuItems @("Yes", "No") `
                -MenuItemFormatter { param($i) "Import module '$($module.Name)'? -> $i" }

            if ($choice -ne "Yes") {
                Write-Host "Skipped." -ForegroundColor Yellow
                continue
            }

            try {
                Import-Module $module.Name -Force -ErrorAction Stop
                $loadedModule = Get-Module -Name $module.Name | Select-Object -First 1
            }
            catch {
                Write-Host "Failed to import module '$($module.Name)'" -ForegroundColor Red
                continue
            }
        }

        $loadedModule.ExportedCommands.Values |
            Sort-Object CommandType, Name |
            Format-Table CommandType, Name, Source, Version -AutoSize
    }
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Show-ModuleCommandsFromMenu.ps1") -Value $publicShowModuleCommandsFromMenu -Encoding UTF8






        $publicShowModuleCommandHelpFromMenu = @'
function Show-ModuleCommandHelpFromMenu {
    param(
        [switch]$All,
        [switch]$Online
    )

    $modules = Get-ModuleStatus -All:$All

    if (-not $modules) {
        Write-Host "No modules found."
        return
    }

    $selectedModule = Show-Menu `
        -MenuItems $modules `
        -MenuItemFormatter {
            param($m)

            $status = if ($m.Imported) { "imported" } else { "not imported" }
            "{0} {1} [{2}]" -f $m.Name, $m.Version, $status
        }

    if (-not $selectedModule) {
        return
    }

    $commands = Get-Command -Module $selectedModule.Name -ErrorAction SilentlyContinue |
        Sort-Object CommandType, Name

    if (-not $commands) {
        Write-Host "No commands found for module '$($selectedModule.Name)'."
        return
    }

    $selectedCommand = Show-Menu `
        -MenuItems $commands `
        -MenuItemFormatter {
            param($c)

            "{0} [{1}]" -f $c.Name, $c.CommandType
        }

    if (-not $selectedCommand) {
        return
    }

    if ($Online) {
        Get-Help $selectedCommand.Name -Online
    }
    else {
        Get-Help $selectedCommand.Name -Full
    }
}
'@

    Set-Content -Path (Join-Path $modulePath "Public\Show-ModuleCommandHelpFromMenu.ps1") -Value $publicShowModuleCommandHelpFromMenu -Encoding UTF8



}