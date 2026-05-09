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

Each entry requires `name` and `installSource`. Supported sources:

| `installSource` | Description |
|---|---|
| `winget` | Installed via winget using `wingetId` (falls back to `name`) |
| `choco` | Installed via Chocolatey using `chocoId` (falls back to `name`) |
| `dotnettool` | Installed/updated via `dotnet tool update --global` using `dotnetToolId` (falls back to `name`) |
| `online` | Downloaded from `url` and run, or executed via `installScriptPath` |
| `local` | Installed from a local/network path relative to `LocalInstallerDirs` in `config.json` |
| `manual` | Opens `url` in the browser and waits for user to confirm manual install |

```json
[
  { "name": "Git", "installSource": "winget", "wingetId": "Git.Git",
    "postInstall": { "scriptPath": "Scripts\\PostInstall\\SetupGit.ps1", "promptMessage": "Run Git setup now?", "continueOnError": true } },
  { "name": "WizTree", "installSource": "choco", "chocoId": "wiztree" },
  { "name": "dotnet-ef", "installSource": "dotnettool", "dotnetToolId": "dotnet-ef" },
  { "name": "FileZilla", "installSource": "manual", "url": "https://filezilla-project.org/download.php?show_all=1",
    "checkPath": "C:\\Program Files\\FileZilla FTP Client\\filezilla.exe" },
  { "name": "bpmanlyz.exe", "installSource": "local", "installerPath": "bpmanlyz.exe" }
]
```

Optional fields per entry:
- `wingetId` / `chocoId` / `dotnetToolId` — package identifier for the respective source
- `checkPath` — skip install if this path exists (supports `%ENVVAR%` expansion)
- `checkService` — skip install if this Windows service is running
- `postInstall` — script to run after install: `scriptPath`, `promptMessage`, `continueOnError`


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

- `setup.ps1` – Run this **first** to create `config/config.json` with your Git identity and local installer paths. Safe to re-run.
- `InstallPowershell.ps1` – Installs the latest PowerShell using winget.
- `InstallApps.ps1` – Installs all applications listed in `config/apps.json` (winget, choco, dotnettool, online, local, and manual sources).
- `InstallPsModules.ps1` – Installs all modules listed in `config/modules.json`.
- `InstallPsProfile.ps1` – Configures your PowerShell profile with module imports and settings.

## Usage

1. Run `setup.ps1` to create your `config/config.json` (Git name, email, local installer paths).
2. Run `InstallPowershell.ps1` in an elevated PowerShell window to install the latest PowerShell.
3. Open a new PowerShell 7 window, then run:
   - `InstallPsModules.ps1` to install all modules
   - `InstallPsProfile.ps1` to set up your profile
   - `InstallApps.ps1` to install all applications from your config

> **Tip:** Run `setup.ps1` before `InstallApps.ps1` — it ensures `config/config.json` exists with your Git identity and local installer directories, which are required by several install steps.

