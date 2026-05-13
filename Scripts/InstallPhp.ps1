$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Helpers\helpers.ps1')
. (Join-Path $PSScriptRoot '..\Helpers\phpInstallHelpers.ps1')

Write-Host ''
Write-Host 'PHP Installation Wizard' -ForegroundColor Cyan
Write-Host '=======================' -ForegroundColor Cyan

# Thread safety
Write-Host ''
Write-Host 'Thread Safety:' -ForegroundColor Cyan
Write-Host '  [1] NTS - Non Thread Safe (recommended for most use, e.g. CLI / VS Code)'
Write-Host '  [2] TS  - Thread Safe (required for Apache mod_php)'
do { $ts = Read-Host 'Enter number (default: 1 = NTS)' }
while ($ts -notin '', '1', '2')
$threadSafety = if ($ts -eq '2') { 'TS' } else { 'NTS' }

# Version
$version = Select-PhpVersion -ThreadSafety $threadSafety

# Extensions
Write-Host ''
Write-Host 'Extensions to enable:' -ForegroundColor Cyan
Write-Host '  Default: curl, openssl, gd, mbstring, mysqli, pdo_mysql, pdo_sqlite, zip'
$extInput = Read-Host 'Enter comma-separated extensions to enable, or press Enter for default'
$enableExtension = if ([string]::IsNullOrWhiteSpace($extInput)) {
    @('curl', 'openssl', 'gd', 'mbstring', 'mysqli', 'pdo_mysql', 'pdo_sqlite', 'zip')
} else {
    $extInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Optional components
Write-Host ''
Write-Host 'Select components to install:' -ForegroundColor Cyan
$noXdebug           = -not (Read-YesNo '  XDebug (debugger + VS Code integration)')
$noComposer         = -not (Read-YesNo '  Composer (PHP package manager)')
$noVsCodeExtensions = -not (Read-YesNo '  VS Code extensions (intelephense, phpunit, xdebug-debug)')

Write-Host ''

Install-Php `
    -Version $version `
    -ThreadSafety $threadSafety `
    -EnableExtension $enableExtension `
    -NoComposer:$noComposer `
    -NoXdebug:$noXdebug `
    -NoVsCodeExtensions:$noVsCodeExtensions
