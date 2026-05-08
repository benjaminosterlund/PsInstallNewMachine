BeforeAll{
    . (Join-Path $PSScriptRoot '..\Helpers\appInstallHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\helpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\onlineAppInstallHelpers.ps1')
}

Describe 'online app helpers' {
    BeforeEach{
        Mock Get-Apps {
            return @(
                @{ name = 'Online1'; installSource = 'online'; url = 'https://example.com/1.exe' },
                @{ name = 'Online2'; installSource = 'online'; url = 'https://example.com/2.exe' },
                @{ name = 'Local1'; installSource = 'local'; installerPath = 'Local1\\setup.exe' }
            )
        }
        Mock Confirm-Action {
            return $true
        }
        Mock Install-AppFromOnlineSource {
            return $true
        }
        Mock Invoke-AppPostInstallAction { $App }
        Mock Test-AppInstalledInRegistry { $false }
    }

    It 'ShouldPromptPerOnlineAppAndInstall' {
        Install-OnlineApps -DownloadDirectory $env:TEMP -Confirm | Out-Null

        Should -Invoke -CommandName Confirm-Action -Times 2
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 2
        Should -Invoke -CommandName Invoke-AppPostInstallAction -Times 2
    }

    It 'ShouldSkipInstallWhenUserDeclines' {
        Mock Confirm-Action {
            return $false
        }

        Install-OnlineApps -DownloadDirectory $env:TEMP -Confirm | Out-Null

        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 0
    }
}
