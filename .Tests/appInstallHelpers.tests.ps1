# Pester https://pester.dev/docs/usage/mocking
BeforeAll{
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')
}

Describe 'installApps' {
    BeforeEach{
        Mock Get-Apps {
            return @(
                @{ name = 'WingetApp'; installSource = 'winget'; wingetId = 'WingetApp.Id' },
                @{ name = 'OnlineApp'; installSource = 'online'; url = 'https://example.com/app.exe' },
                @{ name = 'LocalApp';  installSource = 'local';  installerPath = 'LocalApp\setup.exe' }
            )
        }
        Mock Install-AppFromWinget       { $App }
        Mock Install-AppFromOnlineSource { $App }
        Mock Install-AppFromLocalSource  { $App }
        Mock Invoke-AppPostInstallAction { $App }
        Mock Assert-ChocoAvailable       { $true }
        Mock Test-WingetAppInstalled     { $false }
        Mock Test-AppInstalledInRegistry { $false }
        Mock Get-InstallConfig {
            [PSCustomObject]@{ LocalInstallerDirs = @('C:\Installers') }
        }
    }

    It 'CanRunTest' {
        1 | Should -Be 1
    }

    It 'ShouldRunInstallAppsForAllSources' {
        Install-Apps -DownloadDirectory $env:TEMP

        Should -Invoke -CommandName Install-AppFromWinget       -Times 1
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 1
        Should -Invoke -CommandName Install-AppFromLocalSource  -Times 1
    }

    It 'ShouldFilterByInstallSource' {
        Install-Apps -InstallSource 'winget' -DownloadDirectory $env:TEMP

        Should -Invoke -CommandName Install-AppFromWinget       -Times 1
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 0
        Should -Invoke -CommandName Install-AppFromLocalSource  -Times 0
    }

    It 'ShouldRunInstallWingetAppsWrapper' {
        Install-WingetApps

        Should -Invoke -CommandName Install-AppFromWinget       -Times 1
        Should -Invoke -CommandName Invoke-AppPostInstallAction -Times 1
    }

    It 'ShouldSkipWingetInstallWhenUserDeclines' {
        Mock Confirm-Action { $false }

        Install-WingetApps -Confirm | Out-Null

        Should -Invoke -CommandName Install-AppFromWinget -Times 0
    }
}
