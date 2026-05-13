#Requires -Modules Pester

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\phpInstallHelpers.ps1')
    # Stub Find-WinGetPackage so tests can run without Microsoft.WinGet.Client installed
    if (-not (Get-Command Find-WinGetPackage -ErrorAction SilentlyContinue)) {
        function global:Find-WinGetPackage { param([string]$Id, [string]$Source) }
    }
}

Describe 'Get-PhpAvailableVersions' {
    It 'returns sorted version strings for NTS packages' {
        Mock Find-WinGetPackage {
            @(
                [PSCustomObject]@{ Id = 'PHP.PHP.NTS.8.3' },
                [PSCustomObject]@{ Id = 'PHP.PHP.NTS.8.1' },
                [PSCustomObject]@{ Id = 'PHP.PHP.NTS.8.4' },
                [PSCustomObject]@{ Id = 'PHP.PHP.NTS.8.2' }
            )
        }
        $result = Get-PhpAvailableVersions -ThreadSafety NTS
        $result | Should -Be @('8.1', '8.2', '8.3', '8.4')
    }

    It 'returns sorted version strings for TS packages' {
        Mock Find-WinGetPackage {
            @(
                [PSCustomObject]@{ Id = 'PHP.PHP.8.4' },
                [PSCustomObject]@{ Id = 'PHP.PHP.8.2' }
            )
        }
        $result = Get-PhpAvailableVersions -ThreadSafety TS
        $result | Should -Be @('8.2', '8.4')
    }

    It 'excludes NTS packages when querying TS' {
        Mock Find-WinGetPackage {
            @(
                [PSCustomObject]@{ Id = 'PHP.PHP.8.4' },
                [PSCustomObject]@{ Id = 'PHP.PHP.NTS.8.4' }
            )
        }
        $result = Get-PhpAvailableVersions -ThreadSafety TS
        $result | Should -Be @('8.4')
        $result | Should -Not -Contain 'NTS'
    }

    It 'throws when no matching packages are returned' {
        Mock Find-WinGetPackage { @() }
        { Get-PhpAvailableVersions -ThreadSafety NTS } | Should -Throw
    }
}

Describe 'Get-PhpWingetId' {
    It 'returns NTS id when ThreadSafety is NTS' {
        Get-PhpWingetId -Version '8.4' -ThreadSafety 'NTS' | Should -Be 'PHP.PHP.NTS.8.4'
    }

    It 'returns TS id when ThreadSafety is TS' {
        Get-PhpWingetId -Version '8.3' -ThreadSafety 'TS' | Should -Be 'PHP.PHP.8.3'
    }

    It 'defaults to NTS when ThreadSafety is omitted' {
        Get-PhpWingetId -Version '8.2' | Should -Be 'PHP.PHP.NTS.8.2'
    }
}

Describe 'Enable-PhpExtensionsInIni' {
    BeforeEach {
        $iniContent = @(
            '; comment line',
            ';extension_dir = "ext"',
            ';extension=curl',
            ';extension=openssl',
            ';extension=gd',
            'extension=already_enabled'
        )
        $script:TempIni = Join-Path $TestDrive 'php.ini'
        Set-Content -LiteralPath $script:TempIni -Value ($iniContent -join [Environment]::NewLine) -NoNewline
    }

    It 'uncomments extension_dir' {
        Enable-PhpExtensionsInIni -IniPath $script:TempIni -Extensions @()
        $result = Get-Content $script:TempIni -Raw
        $result | Should -Match 'extension_dir = "ext"'
        $result | Should -Not -Match '^;extension_dir'
    }

    It 'uncomments only requested extensions' {
        Enable-PhpExtensionsInIni -IniPath $script:TempIni -Extensions @('curl', 'openssl')
        $lines = Get-Content $script:TempIni
        $lines | Should -Contain 'extension=curl'
        $lines | Should -Contain 'extension=openssl'
        $lines | Should -Contain ';extension=gd'
    }

    It 'leaves already-enabled extensions untouched' {
        Enable-PhpExtensionsInIni -IniPath $script:TempIni -Extensions @('curl')
        $lines = Get-Content $script:TempIni
        $lines | Should -Contain 'extension=already_enabled'
    }

    It 'does not uncomment extensions not in the list' {
        Enable-PhpExtensionsInIni -IniPath $script:TempIni -Extensions @()
        $lines = Get-Content $script:TempIni
        $lines | Should -Contain ';extension=curl'
        $lines | Should -Contain ';extension=gd'
    }
}

Describe 'Initialize-PhpIni' {
    BeforeEach {
        $script:TempPhpDir = Join-Path $TestDrive 'ini-php'
        New-Item -ItemType Directory -Path $script:TempPhpDir -Force | Out-Null
        $iniDev = Join-Path $script:TempPhpDir 'php.ini-development'
        Set-Content -LiteralPath $iniDev -Value (';extension_dir = "ext"' + [Environment]::NewLine + ';extension=curl') -NoNewline
    }

    It 'copies php.ini-development to php.ini' {
        Initialize-PhpIni -PhpDir $script:TempPhpDir -EnableExtension @()
        Join-Path $script:TempPhpDir 'php.ini' | Should -Exist
    }

    It 'returns the path to the created php.ini' {
        $result = Initialize-PhpIni -PhpDir $script:TempPhpDir -EnableExtension @()
        $result | Should -Be (Join-Path $script:TempPhpDir 'php.ini')
    }

    It 'returns null and warns when php.ini-development is missing' {
        Remove-Item (Join-Path $script:TempPhpDir 'php.ini-development')
        $result = Initialize-PhpIni -PhpDir $script:TempPhpDir -EnableExtension @() -WarningAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }

    It 'enables requested extensions in the created php.ini' {
        Initialize-PhpIni -PhpDir $script:TempPhpDir -EnableExtension @('curl')
        $lines = Get-Content (Join-Path $script:TempPhpDir 'php.ini')
        $lines | Should -Contain 'extension=curl'
    }
}

Describe 'Install-PhpViaWinget' {
    It 'throws when winget exits with a non-success code' {
        Mock winget { $global:LASTEXITCODE = 1 } -Verifiable
        { Install-PhpViaWinget -WingetId 'PHP.PHP.NTS.8.4' } | Should -Throw
    }

    It 'does not throw when winget reports already-installed (exit -1978335189)' {
        Mock winget { $global:LASTEXITCODE = -1978335189 }
        { Install-PhpViaWinget -WingetId 'PHP.PHP.NTS.8.4' } | Should -Not -Throw
    }

    It 'does not throw on success (exit 0)' {
        Mock winget { $global:LASTEXITCODE = 0 }
        { Install-PhpViaWinget -WingetId 'PHP.PHP.NTS.8.4' } | Should -Not -Throw
    }
}

Describe 'Install-Composer' {
    BeforeEach {
        $script:TempPhpDir = Join-Path $TestDrive 'composer-php'
        if (Test-Path -LiteralPath $script:TempPhpDir) {
            Remove-Item -LiteralPath $script:TempPhpDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:TempPhpDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:TempPhpDir 'php.exe') -Value ''
    }

    It 'skips download when composer.phar already exists' {
        Set-Content -LiteralPath (Join-Path $script:TempPhpDir 'composer.phar') -Value ''
        Mock Save-ComposerInstallerScript {}
        Install-Composer -PhpDir $script:TempPhpDir
        Should -Not -Invoke Save-ComposerInstallerScript
    }

    It 'creates composer.ps1 wrapper after successful install' {
        Mock Save-ComposerInstallerScript {}
        Mock Assert-ComposerInstallerHash {}
        Mock Invoke-ComposerSetup {}
        Install-Composer -PhpDir $script:TempPhpDir
        Join-Path $script:TempPhpDir 'composer.ps1' | Should -Exist
    }

    It 'calls Invoke-ComposerSetup with correct php.exe and install dir' {
        Mock Save-ComposerInstallerScript {}
        Mock Assert-ComposerInstallerHash {}
        Mock Invoke-ComposerSetup {}
        Install-Composer -PhpDir $script:TempPhpDir
        Should -Invoke Invoke-ComposerSetup -ParameterFilter {
            $PhpExe    -eq (Join-Path $script:TempPhpDir 'php.exe') -and
            $InstallDir -eq $script:TempPhpDir
        }
    }

    Context 'when installer hash does not match' {
        It 'throws hash mismatch error' {
            Mock Save-ComposerInstallerScript {}
            Mock Assert-ComposerInstallerHash { throw 'hash mismatch' }
            { Install-Composer -PhpDir $script:TempPhpDir } | Should -Throw '*hash mismatch*'
        }
    }
}
