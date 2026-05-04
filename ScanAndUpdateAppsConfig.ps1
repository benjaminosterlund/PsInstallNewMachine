param(
    [switch]$SkipWinget,
    [switch]$SkipLocal,
    [switch]$SkipInstalledPrograms
)

. (Join-Path $PSScriptRoot "Helpers\helpers.ps1")



$appsConfigPath = Join-Path $PSScriptRoot "config\apps.json"

if (-not (Test-Path -LiteralPath $appsConfigPath)) {
    throw "Apps config file not found: $appsConfigPath"
}

$apps = @(Get-Content -LiteralPath $appsConfigPath -Raw | ConvertFrom-Json)
if (-not $apps) {
    $apps = @()
}

function Save-AppsConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Apps,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Apps | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path
}

function Get-WingetPackageRecordsFromObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    $records = @()

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        foreach ($item in $InputObject) {
            $records += @(Get-WingetPackageRecordsFromObject -InputObject $item)
        }
        return $records
    }

    if ($InputObject.PSObject) {
        $propertyNames = @($InputObject.PSObject.Properties.Name)

        $id = $null
        if ($propertyNames -contains "PackageIdentifier") {
            $id = [string]$InputObject.PackageIdentifier
        }
        elseif ($propertyNames -contains "Id") {
            $id = [string]$InputObject.Id
        }

        $name = $null
        if ($propertyNames -contains "PackageName") {
            $name = [string]$InputObject.PackageName
        }
        elseif ($propertyNames -contains "Name") {
            $name = [string]$InputObject.Name
        }

        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $displayName = if ([string]::IsNullOrWhiteSpace($name)) { $id } else { $name }
            $records += [PSCustomObject]@{
                Name = $displayName
                Id = $id
            }
        }

        foreach ($property in $InputObject.PSObject.Properties) {
            if ($null -ne $property.Value -and ($property.Value -is [System.Collections.IEnumerable]) -and -not ($property.Value -is [string])) {
                $records += @(Get-WingetPackageRecordsFromObject -InputObject $property.Value)
            }
        }
    }

    return $records
}

function Get-InstalledProgramCandidatesFromWinget {
    param(
        [switch]$IncludeInstalledPrograms
    )

    $candidates = @()
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        return @()
    }

    if ($IncludeInstalledPrograms) {
        try {
            $listOutput = winget list --output json --accept-source-agreements 2>$null
            if (-not [string]::IsNullOrWhiteSpace([string]$listOutput)) {
                $listData = $listOutput | ConvertFrom-Json
                $candidates += @(Get-WingetPackageRecordsFromObject -InputObject $listData)
            }
        }
        catch {
            Write-Warning "Could not parse 'winget list --output json'. Falling back to winget export only."
        }
    }

    try {
        $exportPath = Join-Path $env:TEMP "psinstall-winget-export.json"
        winget export --output $exportPath --accept-source-agreements 2>$null | Out-Null

        if (Test-Path -LiteralPath $exportPath) {
            $exportData = Get-Content -LiteralPath $exportPath -Raw | ConvertFrom-Json
            $candidates += @(Get-WingetPackageRecordsFromObject -InputObject $exportData)
        }
    }
    catch {
        Write-Warning "Could not parse winget export data."
    }

    $uniqueById = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $uniqueCandidates = @()
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate.Id)) {
            continue
        }

        if ($uniqueById.Add([string]$candidate.Id)) {
            $uniqueCandidates += $candidate
        }
    }

    return @($uniqueCandidates | Sort-Object -Property Id)
}

$existingWingetIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$existingLocalInstallerPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($app in $apps) {
    if ([string]::IsNullOrWhiteSpace($app.installSource) -or [string]::IsNullOrWhiteSpace($app.name)) {
        continue
    }

    $source = $app.installSource.ToLowerInvariant()
    if ($source -eq "winget") {
        if (-not [string]::IsNullOrWhiteSpace($app.name)) {
            [void]$existingWingetIds.Add([string]$app.name)
        }

        if ($app.PSObject.Properties.Name -contains "wingetId" -and -not [string]::IsNullOrWhiteSpace($app.wingetId)) {
            [void]$existingWingetIds.Add([string]$app.wingetId)
        }
    }

    if ($source -eq "local" -and -not [string]::IsNullOrWhiteSpace($app.installerPath)) {
        [void]$existingLocalInstallerPaths.Add([string]$app.installerPath)
    }
}

$didChange = $false

if (-not $SkipWinget) {
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        Write-Warning "winget is not available. Skipping winget scan."
    }
    else {
        $installedProgramCandidates = @(Get-InstalledProgramCandidatesFromWinget -IncludeInstalledPrograms:(-not $SkipInstalledPrograms))

        foreach ($candidate in $installedProgramCandidates) {
            $candidateId = [string]$candidate.Id
            if ($existingWingetIds.Contains($candidateId)) {
                continue
            }

            $candidateName = if ([string]::IsNullOrWhiteSpace($candidate.Name)) { $candidateId } else { [string]$candidate.Name }
            if (Confirm-Action -Message "Add installed program '$candidateName' (winget id '$candidateId') to config/apps.json?") {
                $apps += [PSCustomObject]@{
                    name = $candidateName
                    installSource = "winget"
                    wingetId = $candidateId
                }
                [void]$existingWingetIds.Add($candidateId)
                $didChange = $true
                Write-Host "Added installed program: $candidateName ($candidateId)"
            }
        }
    }
}

if (-not $SkipLocal) {
    $configPath = Join-Path $PSScriptRoot "config\config.json"
    $localInstallerDirs = @()

    if (Test-Path -LiteralPath $configPath) {
        try {
            $installConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            if ($installConfig.PSObject.Properties.Name -contains "LocalInstallerDirs") {
                $localInstallerDirs = @([string[]]$installConfig.LocalInstallerDirs)
            }
            elseif ($installConfig.PSObject.Properties.Name -contains "LocalInstallerDir" -and -not [string]::IsNullOrWhiteSpace($installConfig.LocalInstallerDir)) {
                $localInstallerDirs = @([string]$installConfig.LocalInstallerDir)
            }
        }
        catch {
            Write-Warning "Could not parse config/config.json. Skipping local installer scan."
        }
    }

    $localInstallerDirs = @($localInstallerDirs | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($localInstallerDirs.Count -eq 0) {
        Write-Host "No LocalInstallerDirs configured in config/config.json. Skipping local installer scan."
    }
    else {
        foreach ($baseDir in $localInstallerDirs) {
            if (-not (Test-Path -LiteralPath $baseDir)) {
                Write-Warning "Local installer directory not found, skipping: $baseDir"
                continue
            }

            $installers = Get-ChildItem -LiteralPath $baseDir -Recurse -File |
                Where-Object { $_.Extension -in @('.exe', '.msi') }

            foreach ($installer in $installers) {
                $relativePath = [System.IO.Path]::GetRelativePath($baseDir, $installer.FullName)
                $relativePath = $relativePath -replace '/', '\\'

                if ($existingLocalInstallerPaths.Contains($relativePath)) {
                    continue
                }

                if (Confirm-Action -Message "Add local installer '$relativePath' to config/apps.json?") {
                    $apps += [PSCustomObject]@{
                        name = $installer.Name
                        installSource = "local"
                        installerPath = $relativePath
                        installArgs = @()
                    }
                    [void]$existingLocalInstallerPaths.Add($relativePath)
                    $didChange = $true
                    Write-Host "Added local installer: $relativePath"
                }
            }
        }
    }
}

if ($didChange) {
    Save-AppsConfig -Apps $apps -Path $appsConfigPath
    Write-Host "Saved updates to $appsConfigPath"
}
else {
    Write-Host "No app updates were added."
}
