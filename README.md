# PsInstallNewMachine


Scripts for setting up a new Windows machine with PowerShell modules, apps, and profile configuration.

## Configuration


Install lists and machine-specific settings are stored in JSON files so updates do not require editing script logic.

- PowerShell modules: `config/modules.json`
- Applications: `config/apps.json`
- Machine config: `config/config.json`


### modules.json shape

```json
[
    { "name": "PSGitCompletions", "import": true },
	{ "name": "PowerHTML", "import": false },
]
```

### apps.json shape

```json
[
  { "name": "7zip.7zip", "installSource": "winget" },
  { "name": "Axosoft.GitKraken", "installSource": "winget" },
  { "name": "Dropbox.Dropbox", "installSource": "winget" },
  { "name": "Git.Git", "installSource": "winget", "postInstall": { "scriptPath": "Scripts\\PostInstall\\SetupGit.ps1", "args": [], "promptMessage": "Run Git setup now?", "runWhen": "installed", "continueOnError": true } },
  { "name": "GitHub.cli", "installSource": "winget", "postInstall": { "scriptPath": "Scripts\\PostInstall\\SetupGitHubCliAuth.ps1", "args": [], "promptMessage": "Run GitHub CLI authentication now?", "runWhen": "installed", "continueOnError": true } },
  { "name": "Google.Chrome", "installSource": "winget" },
  { "name": "Mozilla.Firefox.DeveloperEdition", "installSource": "winget" },
  { "name": "Mozilla.Firefox", "installSource": "winget" },
  { "name": "Microsoft.SQLServerManagementStudio", "installSource": "winget" },
  { "name": "Microsoft.VisualStudio.2022.Community", "installSource": "winget" },
  { "name": "Microsoft.VisualStudioCode", "installSource": "winget" }
]
```


For winget apps, `wingetId` is optional but recommended. If omitted, the installer uses `name` as the winget package ID (legacy behavior). Some apps support a `postInstall` script for additional setup.


### config.json (machine-specific settings)

`config/config.json` stores machine-specific values, such as your Git identity and local installer directories:

```json
{
  "GitName": "Your Name",
  "GitEmail": "your@email.com",
  "LocalInstallerDirs": [
    "\\\\BenjiNAS\\home\\Program - install filer",
    "C:\\Users\\oster\\Dropbox\\Program - installationsfiler"
  ]
}
```

Then local app `installerPath` values in `apps.json` should be relative to one of the configured `LocalInstallerDirs`.


## Customization

Edit the JSON files in the `config/` folder to add or remove modules, apps, or change your machine-specific settings.


## Discovery Scripts

Use these scripts to discover installed software/modules and interactively add entries to config files:

- `ScanAndUpdateAppsConfig.ps1`: scans winget apps and local installer files, asks per item before adding to `config/apps.json`
- `ScanAndUpdateModulesConfig.ps1`: scans installed PowerShell modules, asks per item before adding to `config/modules.json`

`ScanAndUpdateAppsConfig.ps1` will, by default, scan installed programs visible via `winget list` and export data, then ask before adding missing entries. Use `-SkipInstalledPrograms` if you only want export-based package discovery.


## Main Scripts

- `InstallPowershell.ps1` – Installs the latest PowerShell using winget.
- `InstallApps.ps1` – Installs all applications listed in `config/apps.json` (winget, online, and local sources).
- `InstallPsModules.ps1` – Installs all modules listed in `config/modules.json`.
- `InstallPsProfile.ps1` – Configures your PowerShell profile with module imports and settings.

## Usage

1. Run `InstallPowershell.ps1` in an elevated PowerShell window to install the latest PowerShell.
2. Open a new PowerShell 7 window, then run:
  - `InstallPsModules.ps1` to install all modules
  - `InstallPsProfile.ps1` to set up your profile
  - `InstallApps.ps1` to install all applications from your config

