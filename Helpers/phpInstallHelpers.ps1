function Get-PhpAvailableVersions {
    param(
        [ValidateSet('TS', 'NTS')]
        [string] $ThreadSafety = 'NTS'
    )
    Import-Module 'Microsoft.WinGet.Client' -ErrorAction SilentlyContinue
    if (-not (Get-Command Find-WinGetPackage -ErrorAction SilentlyContinue)) {
        throw "Microsoft.WinGet.Client module is required. Install it with: Install-Module Microsoft.WinGet.Client"
    }

    $idPrefix = if ($ThreadSafety -eq 'NTS') { 'PHP.PHP.NTS' } else { 'PHP.PHP' }
    $pattern  = if ($ThreadSafety -eq 'NTS') { '^PHP\.PHP\.NTS\.(\d+\.\d+)$' } else { '^PHP\.PHP\.(\d+\.\d+)$' }

    $versions = @(
        Find-WinGetPackage -Id $idPrefix -Source winget -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -match $pattern } |
            ForEach-Object { $Matches[1] } |
            Sort-Object
    )

    if ($versions.Count -eq 0) {
        throw "No PHP $ThreadSafety packages found via winget. Ensure the winget source is available."
    }

    return $versions
}

function Get-PhpWingetId {
    param(
        [Parameter(Mandatory)] [string] $Version,
        [ValidateSet('TS', 'NTS')] [string] $ThreadSafety = 'NTS'
    )
    if ($ThreadSafety -eq 'NTS') { return "PHP.PHP.NTS.$Version" }
    return "PHP.PHP.$Version"
}

function Select-PhpVersion {
    param(
        [ValidateSet('TS', 'NTS')]
        [string] $ThreadSafety = 'NTS'
    )
    $availableVersions = Get-PhpAvailableVersions -ThreadSafety $ThreadSafety
    $defaultVersion    = $availableVersions[-1]
    $defaultIndex      = $availableVersions.Count

    Write-Host ''
    Write-Host 'Select PHP version to install:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $availableVersions.Count; $i++) {
        Write-Host "  [$($i + 1)] PHP $($availableVersions[$i])"
    }

    do {
        $choice = Read-Host "Enter number (default: $defaultIndex = PHP $defaultVersion)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "$defaultIndex" }
    } while ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $availableVersions.Count)

    return $availableVersions[[int]$choice - 1]
}

function Install-PhpViaWinget {
    param(
        [Parameter(Mandatory)] [string] $WingetId
    )
    Write-Host "Installing PHP via winget (id: $WingetId)..." -ForegroundColor Cyan
    winget install --id $WingetId --accept-source-agreements --accept-package-agreements
    # -1978335189 = WINGET_ERROR_ALREADY_INSTALLED — treat as success
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        throw "winget install failed for '$WingetId' (exit code $LASTEXITCODE)."
    }
}

function Update-SessionPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

function Get-PhpDirectory {
    $phpCmd = Get-Command php -ErrorAction SilentlyContinue
    if (-not $phpCmd) { return $null }
    return Split-Path $phpCmd.Source
}

function Enable-PhpExtensionsInIni {
    param(
        [Parameter(Mandatory)] [string]   $IniPath,
        [AllowEmptyCollection()]  [Parameter(Mandatory)] [string[]] $Extensions
    )
    $content = Get-Content $IniPath
    for ($i = 0; $i -lt $content.Length; $i++) {
        $line = $content[$i]
        if ($line -match '^;extension_dir\s*=\s*"ext"') {
            $content[$i] = $line.Substring(1)
            continue
        }
        if ($line -match '^;extension=(?<ext>\S+)') {
            if ($matches.ext -in $Extensions) {
                $content[$i] = $line.Substring(1)
            }
        }
    }
    Set-Content -LiteralPath $IniPath -Value ($content -join [Environment]::NewLine) -NoNewline
}

function Set-PhpIniValue {
    param(
        [Parameter(Mandatory)] [string] $IniPath,
        [Parameter(Mandatory)] [string] $Key,
        [Parameter(Mandatory)] [string] $Value
    )
    $content = Get-Content $IniPath
    $pattern = "^;?\s*$([regex]::Escape($Key))\s*=.*$"
    $replaced = $false
    for ($i = 0; $i -lt $content.Length; $i++) {
        if ($content[$i] -match $pattern) {
            $content[$i] = "$Key = $Value"
            $replaced = $true
            break
        }
    }
    if (-not $replaced) {
        $content += "$Key = $Value"
    }
    Set-Content -LiteralPath $IniPath -Value ($content -join [Environment]::NewLine) -NoNewline
}

function Initialize-PhpIni {
    param(
        [Parameter(Mandatory)] [string]   $PhpDir,
        [AllowEmptyCollection()] [Parameter(Mandatory)] [string[]] $EnableExtension
    )
    $iniSource = Join-Path $PhpDir 'php.ini-development'
    $iniDest   = Join-Path $PhpDir 'php.ini'

    if (-not (Test-Path -LiteralPath $iniSource)) {
        Write-Warning "php.ini-development not found at '$iniSource'. Skipping ini setup."
        return $null
    }

    if (Test-Path -LiteralPath $iniDest) {
        Write-Host "php.ini already exists at: $iniDest — skipping copy, applying settings only." -ForegroundColor Yellow
    } else {
        Copy-Item -LiteralPath $iniSource -Destination $iniDest -Force
    }
    Enable-PhpExtensionsInIni -IniPath $iniDest -Extensions $EnableExtension
    Set-PhpIniValue -IniPath $iniDest -Key 'memory_limit' -Value '1024M'
    Write-Host "php.ini configured at: $iniDest" -ForegroundColor Green
    return $iniDest
}

function Invoke-ComposerSetup {
    param(
        [Parameter(Mandatory)] [string] $PhpExe,
        [Parameter(Mandatory)] [string] $SetupScript,
        [Parameter(Mandatory)] [string] $InstallDir
    )
    & $PhpExe $SetupScript --install-dir=$InstallDir
}

function Save-ComposerInstallerScript {
    param([Parameter(Mandatory)] [string] $OutFile)
    Invoke-WebRequest -Uri 'https://getcomposer.org/installer' -OutFile $OutFile
}

function Get-ComposerSignature {
    (Invoke-RestMethod -Uri 'https://composer.github.io/installer.sig').Trim()
}

function Assert-ComposerInstallerHash {
    param([Parameter(Mandatory)] [string] $SetupFile)
    $expectedHash = Get-ComposerSignature
    $actualHash   = (Get-FileHash -LiteralPath $SetupFile -Algorithm SHA384).Hash
    if ($expectedHash -ine $actualHash) {
        throw "Composer installer hash mismatch. Expected: $expectedHash. Got: $actualHash."
    }
}

function Install-Composer {
    param(
        [Parameter(Mandatory)] [string] $PhpDir
    )

    $composerPhar = Join-Path $PhpDir 'composer.phar'
    if (Test-Path -LiteralPath $composerPhar) {
        Write-Host "Composer already installed at: $composerPhar" -ForegroundColor Yellow
        return
    }

    $composerSetup = Join-Path $env:TEMP 'composer-setup.php'
    try {
        Write-Host 'Downloading Composer installer...'
        Save-ComposerInstallerScript -OutFile $composerSetup
        Assert-ComposerInstallerHash -SetupFile $composerSetup
        Write-Host 'Running Composer installer...'
        Invoke-ComposerSetup -PhpExe (Join-Path $PhpDir 'php.exe') -SetupScript $composerSetup -InstallDir $PhpDir
    }
    catch {
        Write-Error "Composer installation failed: $_"
        return
    }
    finally {
        Remove-Item -LiteralPath $composerSetup -ErrorAction SilentlyContinue
    }

    Set-Content -LiteralPath (Join-Path $PhpDir 'composer.ps1') -Value @'
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(ValueFromRemainingArguments)]
    [ArgumentCompletions("")]
    $Arguments
    ,
    [ArgumentCompleter({ Get-ChildItem -Path:$psscriptroot\php.ini* -Name })]
    [string] $ConfigFile = 'php.ini'
)
Write-Verbose "php -c $psscriptroot\$ConfigFile $psscriptroot\composer.phar $Arguments"
php -c $psscriptroot\$ConfigFile $psscriptroot\composer.phar $Arguments
'@

    Write-Host 'Composer installed.' -ForegroundColor Green
    Write-Host "  composer.phar : $composerPhar"
    Write-Host "  wrapper       : $(Join-Path $PhpDir 'composer.ps1')"
}

function Install-PhpVsCodeExtensions {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Warning "VS Code (code) not found in PATH. Skipping PHP extension install."
        return
    }

    $extensions = @(
        'bmewburn.vscode-intelephense-client',
        'recca0120.vscode-phpunit',
        'xdebug.php-debug'
    )

    Write-Host 'Installing VS Code extensions for PHP...' -ForegroundColor Cyan
    foreach ($ext in $extensions) {
        code --install-extension $ext --force
    }
}

function Get-XDebugReleaseInfo {
    param([Parameter(Mandatory)] [string] $FileName)
    if ($FileName -match '^php_xdebug-(?<xver>[\d.]+)-(?<phpver>\d+\.\d+)-[^-]+(?<nts>-nts)?-x86_64\.dll$') {
        return [PSCustomObject]@{
            FileName   = $FileName
            Version    = [version]$matches.xver
            PhpVersion = $matches.phpver
            IsNTS      = $matches.nts -eq '-nts'
        }
    }
    return $null
}

function Get-XDebugReleases {
    $response = Invoke-WebRequest -Uri 'https://xdebug.org/download/historical' -UseBasicParsing
    foreach ($link in $response.Links) {
        if ($link.href -notmatch 'php_xdebug-[\d.]+-\d+\.\d+-.+-x86_64\.dll') { continue }
        $fileName = Split-Path -Leaf $link.href
        $info = Get-XDebugReleaseInfo -FileName $fileName
        if ($info) {
            [PSCustomObject]@{
                FileName   = $info.FileName
                Version    = $info.Version
                PhpVersion = $info.PhpVersion
                IsNTS      = $info.IsNTS
                Uri        = 'https://xdebug.org' + $link.href
            }
        }
    }
}

function Add-XDebugToPhpIni {
    param(
        [Parameter(Mandatory)] [string] $IniPath
    )
    $content = Get-Content -LiteralPath $IniPath -Raw
    if ($content -match 'zend_extension\s*=\s*xdebug') {
        Write-Host 'XDebug already configured in php.ini.' -ForegroundColor Yellow
        return
    }
    $xdebugConfig = @"

[xdebug]
zend_extension = xdebug
xdebug.mode = debug,develop
xdebug.start_with_request = yes
"@
    Add-Content -LiteralPath $IniPath -Value $xdebugConfig
    Write-Host "XDebug configuration added to: $IniPath" -ForegroundColor Green
}

function Install-XDebug {
    param(
        [Parameter(Mandatory)] [string] $PhpDir,
        [Parameter(Mandatory)] [string] $PhpVersion,
        [ValidateSet('TS', 'NTS')] [string] $ThreadSafety = 'NTS'
    )
    $isNts = $ThreadSafety -eq 'NTS'
    $outPath = Join-Path $PhpDir 'ext\php_xdebug.dll'

    if (-not (Test-Path -LiteralPath $outPath)) {
        Write-Host 'Fetching XDebug releases...' -ForegroundColor Cyan
        $release = Get-XDebugReleases |
            Where-Object { $_.PhpVersion -eq $PhpVersion -and $_.IsNTS -eq $isNts } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $release) {
            Write-Warning "No XDebug release found for PHP $PhpVersion ($ThreadSafety). Skipping XDebug install."
            return
        }

        Write-Host "Downloading XDebug $($release.Version) for PHP $PhpVersion ($ThreadSafety)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $release.Uri -OutFile $outPath -UseBasicParsing
        Write-Host "XDebug dll saved to: $outPath" -ForegroundColor Green
    } else {
        Write-Host "XDebug dll already present at: $outPath" -ForegroundColor Yellow
    }

    $iniPath = Join-Path $PhpDir 'php.ini'
    if (Test-Path -LiteralPath $iniPath) {
        Add-XDebugToPhpIni -IniPath $iniPath
    } else {
        Write-Warning "php.ini not found at '$iniPath'. Run Initialize-PhpIni first."
    }
}

function Install-Php {
    [CmdletBinding()]
    param(
        [string] $Version,

        [ValidateSet('TS', 'NTS')]
        [string] $ThreadSafety = 'NTS',

        [switch] $NoComposer,
        [switch] $NoXdebug,
        [switch] $NoVsCodeExtensions,

        [string[]] $EnableExtension = @('curl', 'openssl', 'gd', 'mbstring', 'mysqli', 'pdo_mysql', 'pdo_sqlite', 'zip')
    )

    if (-not $Version) {
        $Version = Select-PhpVersion -ThreadSafety $ThreadSafety
    }

    $wingetId = Get-PhpWingetId -Version $Version -ThreadSafety $ThreadSafety

    $phpDir = Get-PhpDirectory
    if ($phpDir) {
        $installedVersion = (php --version 2>$null | Select-Object -First 1) -replace '^PHP\s+(\S+).*','$1'
        Write-Host "PHP already installed at: $phpDir (version $installedVersion)" -ForegroundColor Yellow
        Write-Host "Skipping winget install." -ForegroundColor Yellow
    } else {
        Install-PhpViaWinget -WingetId $wingetId
        Update-SessionPath
        $phpDir = Get-PhpDirectory
    }

    if (-not $phpDir) {
        Write-Warning "php.exe was not found in PATH after install. You may need to restart your terminal."
        Write-Warning "Skipping ini setup and Composer install."
        return
    }

    Write-Host "PHP at: $phpDir" -ForegroundColor Green
    php --version

    Initialize-PhpIni -PhpDir $phpDir -EnableExtension $EnableExtension

    if (-not $NoXdebug) {
        Install-XDebug -PhpDir $phpDir -PhpVersion $Version -ThreadSafety $ThreadSafety
    }

    if (-not $NoComposer) {
        Install-Composer -PhpDir $phpDir
    }

    if (-not $NoVsCodeExtensions) {
        Install-PhpVsCodeExtensions
    }

    Write-Host ''
    Write-Host 'PHP setup complete.' -ForegroundColor Green
    Write-Host '  Run ''php --version'' and ''composer --version'' to verify.'
}
