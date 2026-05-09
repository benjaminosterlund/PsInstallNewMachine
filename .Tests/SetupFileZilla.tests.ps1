BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\importHelpers.ps1')

    $script:SetupFileZillaPath = Join-Path $PSScriptRoot '..\Scripts\PostInstall\SetupFileZilla.ps1'
}

Describe 'SetupFileZilla' {

    BeforeEach {
        Mock Get-InstallConfig {
            [PSCustomObject]@{
                FileZillaSiteManagerSource = '\\NAS1\Backups\sitemanager.xml'
            }
        }
        Mock Test-Path { $true }
        Mock Copy-Item {}
        Mock New-Item {}
        Mock Write-Warning {}
        Mock Write-Host {}
    }

    It 'CopiesSiteManagerXmlToAppData' {
        & $script:SetupFileZillaPath

        Should -Invoke Copy-Item -Times 1 -ParameterFilter {
            $Destination -like '*FileZilla*sitemanager.xml'
        }
    }

    It 'BacksUpExistingSiteManagerXml' {
        Mock Test-Path {
            param([string]$LiteralPath)
            # Dest dir exists, dest file exists, source exists
            return $true
        }

        & $script:SetupFileZillaPath

        # Expect two Copy-Item calls: one backup, one real copy
        Should -Invoke Copy-Item -Times 2
    }

    It 'SkipsWhenSourcePathIsEmpty' {
        Mock Get-InstallConfig {
            [PSCustomObject]@{ FileZillaSiteManagerSource = '' }
        }

        & $script:SetupFileZillaPath

        Should -Invoke Copy-Item -Times 0
        Should -Invoke Write-Warning -Times 1
    }

    It 'SkipsWhenSourceFileNotFound' {
        Mock Test-Path {
            param([string]$LiteralPath)
            return $LiteralPath -notlike '*sitemanager.xml*'
        }

        & $script:SetupFileZillaPath

        Should -Invoke Copy-Item -Times 0
        Should -Invoke Write-Warning -Times 1
    }
}
