# dotfiles

My Windows + PowerShell 7 setup: shell profile, terminal, prompt theme, git config, and package exports. Public pieces only: no credentials, no hostnames, no work data.

## Contents

| File | What it is | Restore target |
|---|---|---|
| `$profile.ps1` | PowerShell 7 profile: oh-my-posh prompt (Catppuccin), PSReadLine Catppuccin colors, fastfetch on launch, package-manager aliases (`checkup`, `updateall`, `upchoco`, `upwinget`) | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `catppuccin.omp.json` | oh-my-posh theme (stock Catppuccin) | `D:\Backup\catppuccin.omp.json` (path hardcoded in the profile, adjust to taste) |
| `powershell.config.json` | PowerShell execution policy (`RemoteSigned`) | `~\Documents\PowerShell\powershell.config.json` |
| `WindowsTerminal.settings.json` | Windows Terminal: keybindings, Dracula scheme, CaskaydiaCove Nerd Font Mono | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| `.gitconfig` | git user (GitHub noreply email), Notepad++ as editor | `~\.gitconfig` |
| `fastfetch.config.jsonc` | fastfetch system-info layout | `~\.config\fastfetch\config.jsonc` |
| `winget.json` | WinGet export | import, see below |
| `ChocolateyList.config` | Chocolatey export | import, see below |
| `scoop-packages.json` | Scoop export | import, see below |

## Restore on a new machine

```powershell
# from a fresh clone of this repo
$src = (Get-Location).Path

# PowerShell 7
New-Item "$HOME\Documents\PowerShell" -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $src '$profile.ps1') "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force
Copy-Item "$src\powershell.config.json" "$HOME\Documents\PowerShell\powershell.config.json" -Force

# oh-my-posh theme (or change $ompConfig in the profile to wherever you keep it)
New-Item "D:\Backup" -ItemType Directory -Force | Out-Null
Copy-Item "$src\catppuccin.omp.json" "D:\Backup\catppuccin.omp.json" -Force

# git
Copy-Item "$src\.gitconfig" "$HOME\.gitconfig" -Force

# Windows Terminal (close all Terminal windows first)
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Copy-Item "$src\WindowsTerminal.settings.json" "$wt\settings.json" -Force

# fastfetch
New-Item "$HOME\.config\fastfetch" -ItemType Directory -Force | Out-Null
Copy-Item "$src\fastfetch.config.jsonc" "$HOME\.config\fastfetch\config.jsonc" -Force
```

### Packages

```powershell
winget import -i "$src\winget.json" --accept-package-agreements --accept-source-agreements
choco install "$src\ChocolateyList.config" -y
scoop import "$src\scoop-packages.json"
```

## Refresh the exports

Run these from a clone of this repo, then commit:

```powershell
winget export -o winget.json
choco export --output-file="ChocolateyList.config"
scoop export > scoop-packages.json
```

## Notes

- The `.gitconfig` here uses the GitHub noreply email (`55139207+Timourgv@users.noreply.github.com`) so commits do not expose a personal address.
- Profile dependencies: PowerShell 7, git, oh-my-posh, fastfetch, a Nerd Font (CaskaydiaCove Nerd Font Mono), and the scoop/winget/choco package managers.
