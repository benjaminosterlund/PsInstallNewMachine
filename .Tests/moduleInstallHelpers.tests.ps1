# Pester https://pester.dev/docs/usage/mocking
BeforeAll{
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')
}

Describe 'installModules' {
    BeforeEach{
        Mock Get-PsModules {
            return @(
                @{name = "Module1" },
                @{name = "Module2" },
                @{name = "Module3" }
            )
        }
        Mock Install-Module {
            param(
                [string]$name = ""
            )
            Write-Output "Fake: NOT actually installing $name" -ForeGroundColor Blue
        }
        # Mock - nothing else to do here...
    }

    it "CanRunTest"{
        1 | should -be 1
    }

    It 'ShouldRunInstallPsModules' {
        Install-PsModules 
        Should -Invoke -CommandName Install-Module -Times 3
    }

    It 'ShouldInstallModules' {
        $installedModules = Install-PsModules
        
        $installedModules -Contains "Module1" | Should -Be $true
        $installedModules -Contains "Module2" | Should -Be $true
        $installedModules -Contains "Module3" | Should -Be $true
    }
}