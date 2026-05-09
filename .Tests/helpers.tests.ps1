BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')
}

Describe 'Get-InstallConfig' {

    BeforeEach {
        Mock Set-Content {}
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'ReadsExistingConfigFile' {
        $json = @{
            GitName                    = 'testuser'
            GitEmail                   = 'test@example.com'
            LocalInstallerDirs         = @('C:\Installers')
            FileZillaSiteManagerSource = ''
        } | ConvertTo-Json

        Mock Test-Path { $true }  -ParameterFilter { $LiteralPath -like '*config.json' }
        Mock Get-Content { $json } -ParameterFilter { $LiteralPath -like '*config.json' }

        $config = Get-InstallConfig

        $config.GitName  | Should -Be 'testuser'
        $config.GitEmail | Should -Be 'test@example.com'
    }

    It 'StripsSurroundingQuotesFromLocalInstallerDirs' {
        $json = @{
            GitName                    = 'testuser'
            GitEmail                   = 'test@example.com'
            LocalInstallerDirs         = @('"C:\Installers"', '"\\NAS\share"')
            FileZillaSiteManagerSource = ''
        } | ConvertTo-Json

        Mock Test-Path { $true }  -ParameterFilter { $LiteralPath -like '*config.json' }
        Mock Get-Content { $json } -ParameterFilter { $LiteralPath -like '*config.json' }

        $config = Get-InstallConfig

        $config.LocalInstallerDirs[0] | Should -Be 'C:\Installers'
        $config.LocalInstallerDirs[1] | Should -Be '\\NAS\share'
    }

    It 'AddsFileZillaSiteManagerSourceWhenMissing' {
        $json = @{
            GitName            = 'testuser'
            GitEmail           = 'test@example.com'
            LocalInstallerDirs = @()
        } | ConvertTo-Json

        Mock Test-Path { $true }  -ParameterFilter { $LiteralPath -like '*config.json' }
        Mock Get-Content { $json } -ParameterFilter { $LiteralPath -like '*config.json' }

        $config = Get-InstallConfig

        $config.PSObject.Properties['FileZillaSiteManagerSource'] | Should -Not -BeNullOrEmpty
    }

    It 'MigratesLegacyLocalInstallerDirToArray' {
        $json = @{
            GitName           = 'testuser'
            GitEmail          = 'test@example.com'
            LocalInstallerDir = 'C:\OldDir'
        } | ConvertTo-Json

        Mock Test-Path { $true }  -ParameterFilter { $LiteralPath -like '*config.json' }
        Mock Get-Content { $json } -ParameterFilter { $LiteralPath -like '*config.json' }

        $config = Get-InstallConfig

        $config.LocalInstallerDirs        | Should -Not -BeNullOrEmpty
        $config.LocalInstallerDirs.Count  | Should -Be 1
        $config.LocalInstallerDirs[0]     | Should -Be 'C:\OldDir'
        $config.PSObject.Properties['LocalInstallerDir'] | Should -BeNullOrEmpty
    }

    It 'SavesConfigBackToFile' {
        $json = @{
            GitName                    = 'testuser'
            GitEmail                   = 'test@example.com'
            LocalInstallerDirs         = @()
            FileZillaSiteManagerSource = ''
        } | ConvertTo-Json

        Mock Test-Path { $true }  -ParameterFilter { $LiteralPath -like '*config.json' }
        Mock Get-Content { $json } -ParameterFilter { $LiteralPath -like '*config.json' }

        Get-InstallConfig | Out-Null

        Should -Invoke Set-Content -Times 1 -ParameterFilter { $LiteralPath -like '*config.json' }
    }
}
