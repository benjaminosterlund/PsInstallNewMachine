BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')
}

Describe 'Install-DotnetToolApps' {
    BeforeEach {
        Mock Get-Apps {
            return @(
                @{ name = 'ilspycmd';                       installSource = 'dotnettool'; dotnetToolId = 'ilspycmd' },
                @{ name = 'dotnet-ef';                      installSource = 'dotnettool'; dotnetToolId = 'dotnet-ef' },
                @{ name = 'dotnet-counters';                installSource = 'dotnettool'; dotnetToolId = 'dotnet-counters' },
                @{ name = 'WingetApp';                      installSource = 'winget';     wingetId = 'WingetApp.Id' }
            )
        }
        Mock Assert-DotnetAvailable      { $true }
        Mock Install-AppFromDotnetTool   { }
        Mock Test-AppInstalledInRegistry { $false }
    }

    It 'ShouldCallInstallForEachDotnetToolApp' {
        Install-DotnetToolApps

        Should -Invoke -CommandName Install-AppFromDotnetTool -Times 3
    }

    It 'ShouldNotRunWhenDotnetUnavailable' {
        Mock Assert-DotnetAvailable { $false }

        Install-DotnetToolApps

        Should -Invoke -CommandName Install-AppFromDotnetTool -Times 0
    }
}

Describe 'Install-AppFromDotnetTool' {
    BeforeEach {
        Mock dotnet { }
        $script:DotnetToolListCache = $null
    }

    It 'ShouldRunDotnetToolUpdateWithDotnetToolId' {
        $app = [PSCustomObject]@{ name = 'ilspycmd'; dotnetToolId = 'ilspycmd' }

        Mock dotnet { $global:LASTEXITCODE = 0 } -ParameterFilter { $args -contains 'update' -and $args -contains 'ilspycmd' }

        Install-AppFromDotnetTool -App $app

        Should -Invoke -CommandName dotnet -Times 1 -ParameterFilter { $args -contains 'update' -and $args -contains 'ilspycmd' }
    }

    It 'ShouldFallBackToNameWhenDotnetToolIdMissing' {
        $app = [PSCustomObject]@{ name = 'dotnet-ef' }

        Mock dotnet { $global:LASTEXITCODE = 0 } -ParameterFilter { $args -contains 'update' -and $args -contains 'dotnet-ef' }

        Install-AppFromDotnetTool -App $app

        Should -Invoke -CommandName dotnet -Times 1 -ParameterFilter { $args -contains 'update' -and $args -contains 'dotnet-ef' }
    }

    It 'ShouldWarnOnNonZeroExitCode' {
        $app = [PSCustomObject]@{ name = 'bad-tool'; dotnetToolId = 'bad-tool' }

        Mock dotnet { $global:LASTEXITCODE = 1 }

        Install-AppFromDotnetTool -App $app 3>&1 | Out-Null

        Should -Invoke -CommandName dotnet -Times 1
    }
}

Describe 'Get-DotnetToolId' {
    It 'ShouldReturnDotnetToolIdWhenPresent' {
        $app = [PSCustomObject]@{ name = 'myapp'; dotnetToolId = 'my-dotnet-tool' }

        Get-DotnetToolId $app | Should -Be 'my-dotnet-tool'
    }

    It 'ShouldFallBackToNameWhenDotnetToolIdAbsent' {
        $app = [PSCustomObject]@{ name = 'myapp' }

        Get-DotnetToolId $app | Should -Be 'myapp'
    }

    It 'ShouldFallBackToNameWhenDotnetToolIdIsWhitespace' {
        $app = [PSCustomObject]@{ name = 'myapp'; dotnetToolId = '   ' }

        Get-DotnetToolId $app | Should -Be 'myapp'
    }
}

Describe 'Test-DotnetToolInstalled' {
    BeforeEach {
        $script:DotnetToolListCache = $null
        Mock dotnet {
            @(
                'Package Id      Version      Commands',
                '---------------------------------------------',
                'dotnet-ef        8.0.0        dotnet-ef',
                'ilspycmd         8.9.0        ilspycmd'
            )
        } -ParameterFilter { $args -contains 'list' }
    }

    It 'ShouldReturnTrueForInstalledTool' {
        $app = [PSCustomObject]@{ name = 'dotnet-ef'; dotnetToolId = 'dotnet-ef' }

        Test-DotnetToolInstalled -App $app | Should -BeTrue
    }

    It 'ShouldReturnFalseForNotInstalledTool' {
        $app = [PSCustomObject]@{ name = 'dotnet-trace'; dotnetToolId = 'dotnet-trace' }

        Test-DotnetToolInstalled -App $app | Should -BeFalse
    }

    It 'ShouldBeCaseInsensitive' {
        $app = [PSCustomObject]@{ name = 'ILSpyCmd'; dotnetToolId = 'ilspycmd' }

        Test-DotnetToolInstalled -App $app | Should -BeTrue
    }
}
