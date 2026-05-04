# Pester https://pester.dev/docs/usage/mocking
BeforeAll{
    . (Join-Path $PSScriptRoot '..\Helpers\appInstallHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\helpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\onlineAppInstallHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Helpers\localAppInstallHelpers.ps1')
}

Describe 'installApps' {
    BeforeEach{
        Mock Get-Apps {
            return @(
                @{name = "WingetApp"; installSource = "winget" },
                @{name = "OnlineApp"; installSource = "online"; url = "https://example.com/app.exe" },
                @{name = "LocalApp"; installSource = "local"; installerPath = "\\nas\apps\LocalApp.exe" }
            )
        }
        Mock Install-AppFromWinget {
            param(
                [string]$name = ""
            )
            return $true
        }
        Mock Install-AppFromOnlineSource {
            param(
                [object]$App,
                [string]$DownloadDirectory
            )
            return $true
        }
        Mock Install-AppFromLocalSource {
            param(
                [object]$App
            )
            return $true
        }
        Mock Invoke-AppPostInstallAction {}
        Mock Confirm-Action {
            return $true
        }
    }

    it "CanRunTest"{
        1 | should -be 1
    }

    It 'ShouldRunInstallAppsForAllSources' {
        Install-Apps -DownloadDirectory $env:TEMP

        Should -Invoke -CommandName Install-AppFromWinget -Times 1
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 1
        Should -Invoke -CommandName Install-AppFromLocalSource -Times 1
        Should -Invoke -CommandName Invoke-AppPostInstallAction -Times 3
    }

    It 'ShouldFilterByInstallSource' {
        Install-Apps -InstallSources @("winget") -DownloadDirectory $env:TEMP

        Should -Invoke -CommandName Install-AppFromWinget -Times 1
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 0
        Should -Invoke -CommandName Install-AppFromLocalSource -Times 0
    }

    It 'ShouldRunInstallWingetAppsWrapper' {
        Install-WingetApps

        Should -Invoke -CommandName Confirm-Action -Times 1
        Should -Invoke -CommandName Install-AppFromWinget -Times 1
        Should -Invoke -CommandName Invoke-AppPostInstallAction -Times 1
        Should -Invoke -CommandName Install-AppFromOnlineSource -Times 0
        Should -Invoke -CommandName Install-AppFromLocalSource -Times 0
    }

    It 'ShouldSkipWingetInstallWhenUserDeclines' {
        Mock Confirm-Action {
            return $false
        }

        $installedApps = Install-WingetApps

        $installedApps.Count | Should -Be 0
        Should -Invoke -CommandName Install-AppFromWinget -Times 0
    }

    It 'ShouldReturnInstalledApps' {
        $installedApps = Install-Apps -DownloadDirectory $env:TEMP
        
        $installedApps -Contains "WingetApp" | Should -Be $true
        $installedApps -Contains "OnlineApp" | Should -Be $true
        $installedApps -Contains "LocalApp" | Should -Be $true
    }
}