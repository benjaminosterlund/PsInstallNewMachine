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
