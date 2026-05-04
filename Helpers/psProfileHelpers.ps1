function Set-UserPsProfileFromRepo {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $sourceProfilePath = Join-Path $repoRoot "\Helpers\profile.ps1"

    if (-not (Test-Path -LiteralPath $sourceProfilePath)) {
        throw "profile.ps1 was not found at $sourceProfilePath"
    }

    if (Confirm-Action -Message "Overwrite your PowerShell profile at $($PROFILE.CurrentUserAllHosts)?") {
        Set-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value (Get-Content -LiteralPath $sourceProfilePath)
    }
    else {
        Write-Host "Skipping profile update."
    }
}
