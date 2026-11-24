# dotfiles
My Windows machine backup: PowerShell 7 profile plus package-manager exports.

## Contents

| File | What it is |
| --- | --- |
| `$profile.ps1` | PowerShell 7 profile: cached oh-my-posh init, PSReadLine tuning, lazy-loaded Terminal-Icons, package aliases (`checkup`, `updateall`, `upchoco`, `upwinget`), helper functions (`touch`, `extract`, `rmsoft`, `mkcd`, `myip`, `gpu`, `cmds`, ...), winget/choco tab-completion, fastfetch + startup timing |
| `ChocolateyList.config` | Chocolatey package export of installed packages |
| `winget.json` | WinGet export of installed apps and runtimes (backup of my winget list) |

## Restore

```powershell
# PowerShell 7 profile
Copy-Item "$profile.ps1" "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force

# Chocolatey packages (elevated shell)
choco install ChocolateyList.config -y

# Winget packages
winget import -i winget.json --accept-package-agreements --accept-source-agreements
```

## Refreshing the backups

```powershell
choco export --output-file-path="ChocolateyList.config"
winget export -o "winget.json"
```
