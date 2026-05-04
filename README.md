# PsInstallNewMachine

Scripts for setting up a new Windows machine with PowerShell modules and apps.

## Structure

- `Helpers/moduleInstallHelpers.ps1`: PowerShell module installs
- `Helpers/appInstallHelpers.ps1`: winget app installs
- `Helpers/onlineAppInstallHelpers.ps1`: download and run online installers
- `Helpers/localAppInstallHelpers.ps1`: run installers from local/NAS paths
- `Helpers/helpers.ps1`: shared utility helpers

## Configuration

Install lists are stored in JSON files so updates do not require editing script logic.

- Modules: `config/modules.json`
- All apps: `config/apps.json`

### modules.json shape

```json
[
	{ "name": "Package.Id.Or.ModuleName" }
]
```

### apps.json shape

```json
[
	{ "name": "Git.Git", "installSource": "winget" },
	{ "name": "Git", "installSource": "winget", "wingetId": "Git.Git" },
	{
		"name": "FileZilla",
		"installSource": "online",
		"url": "https://example.com/installer.exe",
		"fileName": "installer.exe",
		"installArgs": ["/quiet"],
		"checkPath": "C:\\Program Files\\FileZilla FTP Client\\filezilla.exe"
	},
	{
		"name": "ExampleNasApp",
		"installSource": "local",
		"installerPath": "ExampleNasApp\\setup.exe",
		"installArgs": ["/S"],
		"checkPath": "C:\\Program Files\\ExampleNasApp"
	}
]
```

For winget apps, `wingetId` is optional but recommended. If omitted, the installer uses `name` as the winget package ID (legacy behavior).

### config.json (local installs)

`Get-InstallConfig` stores machine-specific values in `config/config.json`.

For local installs, set `LocalInstallerDirs` to one or more NAS/local installer roots, for example:

```json
{
	"GitName": "your-name",
	"GitEmail": "you@example.com",
	"LocalInstallerDirs": [
		"\\\\NAS-SERVER\\Installers",
		"D:\\OfflineInstallers"
	]
}
```

Then local app `installerPath` values in `apps.json` should be relative to one of the configured `LocalInstallerDirs`.

## Run

Use PowerShell 7, then run `InstallMachine.ps1`.

## Discovery Scripts

Use these scripts to discover installed software/modules and interactively add entries to config files:

- `ScanAndUpdateAppsConfig.ps1`: scans winget apps and local installer files, asks per item before adding to `config/apps.json`
- `ScanAndUpdateModulesConfig.ps1`: scans installed PowerShell modules, asks per item before adding to `config/modules.json`
- `ScanAndUpdateConfigs.ps1`: runs both scripts above

`ScanAndUpdateAppsConfig.ps1` will, by default, scan installed programs visible via `winget list` and export data, then ask before adding missing entries. Use `-SkipInstalledPrograms` if you only want export-based package discovery.
