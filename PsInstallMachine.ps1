$myConfig = @{
    [string] $GitEmail = "your@email.com"
    [string] $GitName = "Your Name"
}

$dirDocuments = "$env:USERPROFILE\Documents"
$dirDownloads = "$env:USERPROFILE\Downloads"
$dirRepositories = "$dirDocuments\source\repos"

## Install Ps modules
.\installPsModules.ps1
Install-PsModules


# Set profile.ps1
Set-Content -LiteralPath $PROFILE.CurrentUserAllHosts -value (Get-Content -LiteralPath .\profile.ps1)



# Install programs




Write-Output "Installing Apps"
$wingetApps = @(
    @{name = "7zip.7zip" },
    @{name = "Axosoft.GitKraken" },
    @{name = "Dropbox.Dropbox" },
    @{name = "Git.Git" },
    @{name = "GitHub.cli" },
    @{name = "Google.Chrome" },
    @{name = "Mozilla.Firefox.DeveloperEdition" },
    @{name = "Mozilla.Firefox" },
    @{name = "Microsoft.SQLServerManagementStudio" }, # Includes AzureDataStudio
    @{name = "Microsoft.VisualStudio.2022.Community" },
    @{name = "Microsoft.VisualStudioCode" },
    @{name = "Microsoft.WindowsTerminal" },
    @{name = "OpenJS.NodeJS" }, # NodeJs
    @{name = "TimKosse.FileZilla.Client" },
    @{name = "VideoLAN.VLC" },
    @{name = "Microsoft.Teams" },
    @{name = "Zoom.Zoom" },
    @{name = "Microsoft.SQLServer.2022.Express" },
    @{name = "Microsoft.Sqlcmd" }
);


Foreach ($app in $wingetApps) {
    $listApp = winget list --exact -q $app.name
    if (![String]::Join("", $listApp).Contains($app.name)) {
        Write-host "Installing: " $app.name
        winget install -e -h --accept-source-agreements --accept-package-agreements --id $app.name 
    }
    else {
        Write-host "Skipping: " $app.name " (already installed)"
    }
}




# Log into VsCode with github account
code 
Read-Host "Log into VsCode with your github account and press enter to continue"


# Install FileZilla
Invoke-RestMethod -Path "https://download.filezilla-project.org/client/FileZilla_3.68.1_win64_sponsored2-setup.exe" -OutFile (Join-Path $dirDownloads "FileZilla_3.68.1_win64_sponsored2-setup.exe")
Start-Process -FilePath (Join-Path $dirDownloads "FileZilla_3.68.1_win64_sponsored2-setup.exe") -Wait
Read-Host "Install FileZilla and press enter to continue"


# Install php with PsPhpInstall
# Not implemented yet


# create Local Repositories
mkdir $dirRepositories

#Set git Credentials
git config --global user.name $myConfig.GitName
git config --global user.email $myConfig.GitEmail
git config --global init.defaultBranch main

Write-Host "Done!"