function Get-Apps
{
    $configPath = Join-Path $PSScriptRoot "..\config\apps.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Apps config file not found: $configPath"
    }

    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

function Get-AppsBySource
{
    param(
        [Parameter(Mandatory)]
        [string]$InstallSource
    )

    return @(Get-Apps | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.installSource) -and $_.installSource.ToLowerInvariant() -eq $InstallSource.ToLowerInvariant()
    })
}

function Where-AppShouldInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App,

        [switch]$Confirm
    )

    process {
        $name = $App.Name
        $source = if (-not [string]::IsNullOrWhiteSpace($App.installSource)) { $App.installSource.ToLowerInvariant() } else { 'unknown' }

        Write-Verbose "[$source] Evaluating: $name"

        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Warning "Skipping $source app entry due to missing name."
            return
        }


        $svc = if (-not [string]::IsNullOrWhiteSpace($App.checkService)) {
            Get-Service -Name $App.checkService -ErrorAction SilentlyContinue
        }
        if ($svc -and $svc.Status -eq 'Running') {
            Write-Host "Skipping: $name (service running: $($App.checkService))" -ForegroundColor Yellow
            return
        }

        $isInstalled = switch ($source) {
            'winget' { Test-WingetAppInstalled  -App $App; break }
            'choco'  { Test-ChocoAppInstalled   -App $App; break }
            'dotnettool' { Test-DotnetToolInstalled -App $App; break }
            default  { $false }
        }

        if (-not $isInstalled -and -not [string]::IsNullOrWhiteSpace($App.checkPath)) {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($App.checkPath)
            $isInstalled = Test-Path -LiteralPath $expandedPath
            if ($isInstalled) { Write-Verbose "[$source] Found by checkPath '$expandedPath'" }
        }

        if (-not $isInstalled) {
            $isInstalled = Test-AppInstalledInRegistry -Name $name
            if ($isInstalled) { Write-Verbose "[$source] Found by registry display name '$name'" }
        }

        if ($isInstalled) {
            Write-Host "Skipping: $name (already installed)" -ForegroundColor Yellow
            return
        }

        if ($Confirm -and -not (Confirm-Action -Message "Install $source app '$name'?")) {
            Write-Verbose "[$source] User skipped: $name"
            Write-Host "Skipping $source app: $name"
            return
        }

        Write-Verbose "[$source] Queuing for install: $name"
        $App
    }
}


$script:WingetInstalledCache = $null
$script:ChocoInstalledText = $null
$script:RegistryInstalledCache = $null

function Get-RegistryInstalledCache {
    if ($null -ne $script:RegistryInstalledCache) { return $script:RegistryInstalledCache }

    Write-Verbose "[registry] Building installed apps cache..."
    $script:RegistryInstalledCache = @{}

    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            ForEach-Object { $script:RegistryInstalledCache[$_.DisplayName] = $true }
    }

    $script:RegistryInstalledCache
}

function Test-AppInstalledInRegistry {
    param([Parameter(Mandatory)][string]$Name)
    $cache = Get-RegistryInstalledCache
    if ($cache.ContainsKey($Name)) { return $true }
    # Also check if any registry entry starts with the app name (catches "Git version 2.x")
    return [bool]($cache.Keys | Where-Object { $_ -like "$Name*" } | Select-Object -First 1)
}

function Get-ChocoInstalledText {
    if ($null -eq $script:ChocoInstalledText) {
        Write-Verbose "[choco] Building installed cache..."
        $script:ChocoInstalledText = [string]::Join("`n", (choco search --local-only --limit-output 2>$null))
    }

    $script:ChocoInstalledText
}

function Get-WingetInstalledCache {
    if ($null -ne $script:WingetInstalledCache) { return $script:WingetInstalledCache }

    Write-Verbose "[winget] Building installed cache via Microsoft.WinGet.Client..."
    Import-Module 'Microsoft.WinGet.Client' -ErrorAction SilentlyContinue
    $script:WingetInstalledCache = @{}
    $packages = Get-WinGetPackage -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        if ($pkg.Id)   { $script:WingetInstalledCache[$pkg.Id]   = $true }
        if ($pkg.Name) { $script:WingetInstalledCache[$pkg.Name] = $true }
    }

    $script:WingetInstalledCache
}

function Test-WingetAppInstalled {
    param(
        [Parameter(Mandatory)]
        [object]$App
    )

    $effectiveId = if ($App.PSObject.Properties['wingetId'] -and
        -not [string]::IsNullOrWhiteSpace($App.wingetId)) {
        $App.wingetId
    } else {
        $App.Name
    }

    if (Get-Module -ListAvailable -Name 'Microsoft.WinGet.Client' -ErrorAction SilentlyContinue) {
        $cache = Get-WingetInstalledCache
        if ($cache.ContainsKey($effectiveId)) {
            Write-Verbose "[winget] Found by id '$effectiveId' (module cache)"
            return $true
        }
        if ($cache.ContainsKey($App.Name)) {
            Write-Verbose "[winget] Found by name '$($App.Name)' (module cache)"
            return $true
        }
        return $false
    }

    Write-Verbose "[winget] Checking installed (no module): $effectiveId"
    $byId   = @(winget list --id   $effectiveId --exact --accept-source-agreements 2>$null) | Where-Object { $_ -match [regex]::Escape($effectiveId) }
    $byName = @(winget list --name $App.Name    --exact --accept-source-agreements 2>$null) | Where-Object { $_ -match [regex]::Escape($App.Name) }
    if ($byId.Count -gt 0) {
        Write-Verbose "[winget] Found by id '$effectiveId' (winget list --id)"
        return $true
    }
    if ($byName.Count -gt 0) {
        Write-Verbose "[winget] Found by name '$($App.Name)' (winget list --name)"
        return $true
    }
    return $false
}

function Test-ChocoAppInstalled {
    param(
        [Parameter(Mandatory)]
        [object]$App
    )

    $effectiveId = if ($App.PSObject.Properties['chocoId'] -and
        -not [string]::IsNullOrWhiteSpace($App.chocoId)) {
        $App.chocoId
    } else {
        $App.Name
    }

    $installed = Get-ChocoInstalledText

    return $installed -match "(?m)^$([regex]::Escape($effectiveId))\|"
}



function Invoke-AppPostInstallAction
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$App
    )

    process {

    if(-not $App){
        Write-Warning "Invoke-AppPostInstallAction received null/empty app object. Skipping."
        return
    }

    Write-Verbose "[post-install] Checking post-install for: $($App.name)"

    if (-not $App.PSObject.Properties['postInstall'] -or -not $App.postInstall) {
        Write-Verbose "[post-install] No postInstall config for: $($App.name)"
        $App; return
    }

    $postInstall = $App.postInstall

    if (-not $postInstall.PSObject.Properties['scriptPath'] -or [string]::IsNullOrWhiteSpace($postInstall.scriptPath)) {
        Write-Warning "Skipping post-install for $($App.name): scriptPath is missing."
        $App; return
    }

    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $scriptPath = [string]$postInstall.scriptPath
    $resolvedScriptPath = if ([System.IO.Path]::IsPathRooted($scriptPath)) {
        $scriptPath
    }
    else {
        Join-Path $repoRoot $scriptPath
    }

    if (-not (Test-Path -LiteralPath $resolvedScriptPath)) {
        Write-Warning "Skipping post-install for $($App.name): script not found at '$resolvedScriptPath'."
        $App; return
    }

    $promptMessage = "Run post-install script for '$($App.name)'?"
    if ($postInstall.PSObject.Properties['promptMessage'] -and -not [string]::IsNullOrWhiteSpace($postInstall.promptMessage)) {
        $promptMessage = [string]$postInstall.promptMessage
    }

    if (-not (Confirm-Action -Message $promptMessage)) {
        Write-Host "Skipping post-install for $($App.name)."
        $App; return
    }

    $argumentList = @()
    if ($postInstall.PSObject.Properties['args'] -and $postInstall.args) {
        $argumentList += [string[]]$postInstall.args
    }

    $continueOnError = $false
    if ($postInstall.PSObject.Properties['continueOnError']) {
        $continueOnError = [bool]$postInstall.continueOnError
    }

    try {
        Write-Verbose "[post-install] Running post-install script for: $($App.name)"
        & $resolvedScriptPath @argumentList
        Write-Host "$($App.name) setup complete." -ForegroundColor Green
        Write-Verbose "[post-install] Script finished for: $($App.name)"
    }
    catch {
        if ($continueOnError) {
            Write-Warning "Post-install failed for $($App.name): $($_.Exception.Message)"
        }
        else {
            throw
        }
    }

    $App
    }
}

function Install-Apps
{
    param(
        [ValidateSet('winget', 'choco', 'dotnettool', 'online', 'local', 'manual')]
        [string]$InstallSource = '',
        [string]$DownloadDirectory = (Join-Path $env:TEMP "PsInstallNewMachine"),
        [switch]$Confirm
    )

    $dispatch = [ordered]@{
        'winget'  = { Install-WingetApps      -Confirm:$Confirm }
        'choco'   = { Install-ChocoApps       -Confirm:$Confirm }
        'dotnettool' = { Install-DotnetToolApps -Confirm:$Confirm }
        'online'  = { Install-OnlineApps -DownloadDirectory $DownloadDirectory -Confirm:$Confirm }
        'local'   = { Install-LocalApps  -Confirm:$Confirm }
        'manual'  = { Install-ManualApps -Confirm:$Confirm }
    }

    $sources = if (-not [string]::IsNullOrWhiteSpace($InstallSource)) {
        @($InstallSource.ToLowerInvariant())
    } else {
        $dispatch.Keys
    }

    foreach ($source in $sources) {
        & $dispatch[$source]
    }
}

