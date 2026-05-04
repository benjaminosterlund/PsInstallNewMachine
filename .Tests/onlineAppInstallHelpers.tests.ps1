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
    }

    It 'ShouldPromptPerOnlineAppAndInstall' {
        Install-OnlineApps -DownloadDirectory $env:TEMP | Out-Null

        Should -Invoke -CommandName Confirm-Action -Times 2
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 2
    }

    It 'ShouldReturnInstalledOnlineApps' {
        $installed = Install-OnlineApps -DownloadDirectory $env:TEMP
        $installed -Contains 'Online1' | Should -Be $true
        $installed -Contains 'Online2' | Should -Be $true
    }

    It 'ShouldSkipInstallWhenUserDeclines' {
        Mock Confirm-Action {
            return $false
        }

        $installed = Install-OnlineApps -DownloadDirectory $env:TEMP

        $installed.Count | Should -Be 0
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 0
    }
}
