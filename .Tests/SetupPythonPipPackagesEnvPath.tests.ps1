BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')

    $script:ScriptPath = Join-Path $PSScriptRoot '..\Scripts\PostInstall\SetupPythonPipPackagesEnvPath.ps1'
    . $script:ScriptPath
}

Describe 'Add-PathEntry' {

    It 'AddsEntryWhenMissing' {
        $result = Add-PathEntry -PathValue 'C:\Windows;C:\Tools' -Entry 'C:\Python\Scripts'

        $result | Should -Be 'C:\Windows;C:\Tools;C:\Python\Scripts'
    }

    It 'DoesNotDuplicateExistingEntry' {
        $entry = 'C:\Python\Scripts'

        $result = Add-PathEntry -PathValue "C:\Windows;$entry" -Entry $entry

        ($result -split ';' | Where-Object { $_ -eq $entry }).Count | Should -Be 1
    }

    It 'HandlesEmptyPathValue' {
        $result = Add-PathEntry -PathValue '' -Entry 'C:\Python\Scripts'

        $result | Should -Be 'C:\Python\Scripts'
    }

    It 'IgnoresBlankSegments' {
        $result = Add-PathEntry -PathValue 'C:\Windows;;C:\Tools' -Entry 'C:\Python\Scripts'

        $result | Should -Not -BeLike '*;;*'
    }
}

Describe 'Setup-PythonPipPackagesEnvPath' {

    BeforeEach {
        Mock Test-Path { $true }
        Mock Write-Warning {}
        Mock Write-Host {}
        Mock Get-UserEnvPath { 'C:\SomeOtherPath' }
        Mock Set-UserEnvPath {}
    }

    It 'AddsScriptsDirToUserPathWhenMissing' {
        Setup-PythonPipPackagesEnvPath

        Should -Invoke Set-UserEnvPath -Times 1 -ParameterFilter {
            $Value -like '*Python314\Scripts*'
        }
    }

    It 'DoesNotModifyPathWhenAlreadyPresent' {
        $pythonScripts = Join-Path $env:APPDATA 'Python\Python314\Scripts'
        Mock Get-UserEnvPath { "C:\SomeOtherPath;$pythonScripts" }

        Setup-PythonPipPackagesEnvPath

        Should -Invoke Set-UserEnvPath -Times 0
    }

    It 'SkipsWhenScriptsDirDoesNotExist' {
        Mock Test-Path { $false }

        Setup-PythonPipPackagesEnvPath

        Should -Invoke Write-Warning -Times 1
        Should -Invoke Set-UserEnvPath -Times 0
    }
}
