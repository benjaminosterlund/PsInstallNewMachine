BeforeAll{
    . (Join-Path $PSScriptRoot '..\Helpers\appInstallHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\helpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\localAppInstallHelpers.ps1')
}

Describe 'local app helpers' {
    BeforeEach{
        Mock Get-Apps {
            return @(
                @{ name = 'Local1'; installSource = 'local'; installerPath = 'Local1\\setup.exe' },
                @{ name = 'Local2'; installSource = 'local'; installerPath = 'Local2\\setup.exe' },
                @{ name = 'Online1'; installSource = 'online'; url = 'https://example.com/online.exe' }
            )
        }
        Mock Confirm-Action {
            return $true
        }
        Mock Install-AppFromLocalSource {
            return $true
        }
    }

    It 'ShouldPromptPerLocalAppAndInstall' {
        Install-LocalApps | Out-Null

        Should -Invoke -CommandName Confirm-Action -Times 2
        Should -Invoke -CommandName Install-AppFromLocalSource -Times 2
    }

    It 'ShouldReturnInstalledLocalApps' {
        $installed = Install-LocalApps
        $installed -Contains 'Local1' | Should -Be $true
        $installed -Contains 'Local2' | Should -Be $true
    }

    It 'ShouldSkipInstallWhenUserDeclines' {
        Mock Confirm-Action {
            return $false
        }

        $installed = Install-LocalApps

        $installed.Count | Should -Be 0
        Should -Invoke -CommandName Install-AppFromLocalSource -Times 0
    }
}

Describe 'Install-AppFromLocalSource' {
    It 'ShouldResolveInstallerPathFromConfiguredLocalInstallerDirs' {
        Mock Get-InstallConfig {
            [PSCustomObject]@{ LocalInstallerDirs = @('\\NAS1\Installers', '\\NAS2\Installers') }
        }
        Mock Test-Path {
            param([string]$LiteralPath)
            return $LiteralPath -like '*NAS2*LocalTool*setup.exe'
        }
        Mock Start-Process {
            [PSCustomObject]@{ ExitCode = 0 }
        }

        $result = Install-AppFromLocalSource -App @{
            name = 'LocalTool'
            installerPath = 'LocalTool\setup.exe'
            installArgs = @('/S')
        }

        $result | Should -Be $true
        Should -Invoke -CommandName Start-Process -Times 1 -ParameterFilter { $FilePath -like '*NAS2*LocalTool*setup.exe' }
    }

    It 'ShouldSkipWhenLocalInstallerDirsMissing' {
        Mock Get-InstallConfig {
            [PSCustomObject]@{ LocalInstallerDirs = @() }
        }

        $result = Install-AppFromLocalSource -App @{
            name = 'LocalTool'
            installerPath = 'LocalTool\setup.exe'
        }

        $result | Should -Be $false
    }
}
