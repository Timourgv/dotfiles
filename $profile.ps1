# ==============================================================================
# POWERSHELL 7 PROFILE (Optimized for Speed & Windows Terminal)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. FAST OH-MY-POSH INIT (Cached script loading)
# ------------------------------------------------------------------------------
$ompCache  = "$env:TEMP\omp_cache.ps1"
$ompConfig = 'D:\Backup\catppuccin.omp.json'
$ompCmd    = Get-Command oh-my-posh -ErrorAction SilentlyContinue

if ($ompCmd) {
    $cacheInvalid = -not (Test-Path $ompCache) -or
        ([System.IO.File]::GetLastWriteTime($ompCache) -lt [System.IO.File]::GetLastWriteTime($ompCmd.Source)) -or
        ((Test-Path $ompConfig) -and ([System.IO.File]::GetLastWriteTime($ompCache) -lt [System.IO.File]::GetLastWriteTime($ompConfig))) -or
        ([System.IO.File]::GetLastWriteTime($ompCache) -lt (Get-Date).AddDays(-7))

    if ($cacheInvalid) {
        oh-my-posh init pwsh --config $ompConfig | Out-File $ompCache -Encoding utf8
    }
    . $ompCache
}

# ------------------------------------------------------------------------------
# 2. PSREADLINE, KEYBINDINGS & CATPPUCCIN $PSSTYLE
# ------------------------------------------------------------------------------
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -MaximumHistoryCount 8192  # default is 4096

# Completion, prediction toggle & history navigation
Set-PSReadLineKeyHandler -Key Tab              -Function MenuComplete
Set-PSReadLineKeyHandler -Key F2               -Function SwitchPredictionView
Set-PSReadLineKeyHandler -Key UpArrow          -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow        -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key 'Alt+.'          -Function YankLastArg
Set-PSReadLineKeyHandler -Key 'Ctrl+Backspace' -Function BackwardKillWord

# Catppuccin Mocha accents for native file listings
$PSStyle.FileInfo.Directory    = "`e[38;2;203;166;247m" # Mauve
$PSStyle.FileInfo.SymbolicLink = "`e[38;2;116;199;236m" # Sapphire
$PSStyle.FileInfo.Executable   = "`e[38;2;166;227;161m" # Green

# ------------------------------------------------------------------------------
# 3. LAZY-LOADED TERMINAL ICONS (Loads on first 'ls' / 'dir' execution)
# ------------------------------------------------------------------------------
function ls {
    if (-not (Get-Module -Name Terminal-Icons)) {
        Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
    }
    Get-ChildItem @args
}
Set-Alias -Name dir -Value ls -Option AllScope -Force

# ------------------------------------------------------------------------------
# 4. CUSTOM FUNCTIONS & ALIASES
# ------------------------------------------------------------------------------

# --- Elevation Helper ---
function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

# --- Package Management ---

# 1. Upgrade Chocolatey only
function Update-Choco {
    Write-Host "==> Upgrading Chocolatey packages..." -ForegroundColor Cyan
    sudo choco upgrade all -y
}

# 2. Upgrade Winget (all or specific app)
function Update-Winget {
    param([string]$PackageId)
    $flags = @('--silent', '--accept-package-agreements', '--accept-source-agreements')
    if ($PackageId) {
        Write-Host "==> Upgrading Winget package: $PackageId..." -ForegroundColor Cyan
        winget upgrade --id $PackageId @flags
    } else {
        Write-Host "==> Upgrading all Winget packages..." -ForegroundColor Cyan
        winget upgrade --all @flags
    }
}

# Helper: Run 'winget upgrade' without footer notices for pinned/unknown packages
function Get-WingetPending {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    winget upgrade | Where-Object {
        $_ -notmatch 'cannot be determined|have pins that prevent upgrade|--include-unknown|--include-pinned' -and
        $_ -notmatch '^\s*[-\\|/]\s*$'
    }
}

# 3. Check for pending updates across all managers (non-destructive)
function Get-PackageUpdates {
    Write-Host "==> Checking Chocolatey..." -ForegroundColor Cyan
    choco outdated

    Write-Host "`n==> Checking Winget..." -ForegroundColor Cyan
    Get-WingetPending

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "`n==> Checking Scoop..." -ForegroundColor Cyan
        scoop status
    }
}

# 4. Standard workflow: Auto-upgrade Choco, then list Winget updates to inspect
function Update-System {
    Write-Host "==> Upgrading Chocolatey packages..." -ForegroundColor Cyan
    sudo choco upgrade all -y

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "`n==> Updating Scoop buckets..." -ForegroundColor Cyan
        # No bucket-only refresh exists in scoop; pull the bucket git repos directly
        $scoopHome = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
        Get-ChildItem "$scoopHome\buckets" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { git -C $_.FullName pull -q }
    }

    Write-Host "`n==> Pending Winget updates:" -ForegroundColor Cyan
    Get-WingetPending
}

Set-Alias checkup   Get-PackageUpdates
Set-Alias updateall Update-System
Set-Alias upchoco   Update-Choco
Set-Alias upwinget  Update-Winget

# --- Small Helpers (touch, extract & safe delete) ---
# touch: update timestamp or create empty file(s), like Unix touch
function touch {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    foreach ($p in $Path) {
        if (Test-Path $p) { (Get-Item $p).LastWriteTime = Get-Date }
        else { New-Item -ItemType File -Path $p | Out-Null }
    }
}

# extract: unzip or untar any archive into the current folder
function extract {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { Write-Host "Archive not found: $Path" -ForegroundColor Red; return }
    switch -Regex ($Path) {
        "\.zip$" { Expand-Archive -Path $Path -DestinationPath (Get-Location).Path }
        "\.tar$|\.tar\.(gz|bz2|xz)$|\.t(gz|bz2|xz)$" { tar -xf $Path }
        default { Write-Host "Unsupported archive type: $Path" -ForegroundColor Red }
    }
}

# rmsoft: send file(s)/folder(s) to the Recycle Bin instead of deleting permanently
function rmsoft {
    param([Parameter(Mandatory)][string[]]$Path)
    Add-Type -AssemblyName Microsoft.VisualBasic
    foreach ($p in $Path) {
        if (-not (Test-Path $p)) { Write-Host "Not found: $p" -ForegroundColor Red; continue }
        $full = (Resolve-Path $p).Path
        if (Test-Path $full -PathType Container) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($full, "OnlyErrorDialogs", "SendToRecycleBin")
            } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($full, "OnlyErrorDialogs", "SendToRecycleBin")
        }
        Write-Host "Recycled: $p" -ForegroundColor Green
    }
}

# --- Gaming & Modding (Vortex Launcher with Tab-Completion) ---
function Open-VortexGame {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $vortexData = "$env:APPDATA\Vortex"
            if (Test-Path $vortexData) {
                $excluded = @(
                    'blob_storage', 'Cache', 'Code Cache', 'CrashDumps', 'databases',
                    'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache', 'dictionaries',
                    'GPUCache', 'IndexedDB', 'Local Storage', 'logs', 'metaserver',
                    'Network', 'plugins', 'sentry', 'Session Storage', 'Shared Dictionary',
                    'temp', 'WebStorage'
                )
                Get-ChildItem -Path $vortexData -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notin $excluded -and $_.Name -notlike 'state*' -and $_.Name -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', "Vortex game: $($_.Name)")
                    }
            }
        })]
        [string]$GameId,

        [Parameter(Position = 1)]
        [string]$ProfileId
    )

    $vortexExe = "${env:ProgramFiles}\Black Tree Gaming Ltd\Vortex\Vortex.exe"
    if (-not (Test-Path $vortexExe)) {
        $regPath = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Vortex*' -and $_.InstallLocation } |
            Select-Object -First 1 -ExpandProperty InstallLocation
        if ($regPath) {
            $vortexExe = Join-Path $regPath 'Vortex.exe'
        }
    }

    if (-not (Test-Path $vortexExe)) {
        Write-Host "Vortex.exe not found. Check your installation path." -ForegroundColor Red
        return
    }

    $vortexArgs = @("--game", $GameId)
    if ($ProfileId) {
        $vortexArgs += @("--profile", $ProfileId)
    }

    Start-Process -FilePath $vortexExe -ArgumentList $vortexArgs
}
Set-Alias vortexgame Open-VortexGame

# --- Vanguard Management (Requires elevation) ---
function Stop-Vanguard {
    if (-not (Test-IsAdmin)) {
        Write-Host "Run this from an elevated terminal (or via sudo) to modify Vanguard services." -ForegroundColor Red
        return
    }
    Write-Host "Disabling & Stopping Vanguard..." -ForegroundColor Yellow
    Set-Service -Name "vgc" -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name "vgk" -StartupType Disabled -ErrorAction SilentlyContinue

    Stop-Service -Name "vgc" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "vgk" -Force -ErrorAction SilentlyContinue

    Stop-Process -Name "vgtray" -Force -ErrorAction SilentlyContinue
    Write-Host "Vanguard is completely off." -ForegroundColor Green
}

function Start-VanguardReboot {
    if (-not (Test-IsAdmin)) {
        Write-Host "Run this from an elevated terminal (or via sudo) to modify Vanguard services." -ForegroundColor Red
        return
    }
    Write-Host "Enabling Vanguard & Rebooting..." -ForegroundColor Red
    Set-Service -Name "vgc" -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name "vgk" -StartupType System -ErrorAction SilentlyContinue
    Restart-Computer -Force
}

Set-Alias stopvg  Stop-Vanguard
Set-Alias startvg Start-VanguardReboot

# --- Hardware & Network Helpers ---
function Get-HyperThreadStatus {
    Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
}
Set-Alias hypert Get-HyperThreadStatus

function Get-NetAdapters {
    Get-NetAdapter | Format-Table Name, InterfaceDescription -AutoSize
}
function Ethernet-On  { Enable-NetAdapter -Name "Ethernet" }
function Ethernet-Off { Disable-NetAdapter -Name "Ethernet" }

Set-Alias getnet      Get-NetAdapters
Set-Alias etherneton  Ethernet-On
Set-Alias ethernetoff Ethernet-Off

# --- Quick Public & Local IP ---
function Get-MyIP {
    $publicIP = try {
        (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 3).ip
    } catch {
        "Unavailable"
    }
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","Wi-Fi*" -AddressState Preferred -ErrorAction SilentlyContinue).IPAddress
    [PSCustomObject]@{
        LocalIP  = $localIP -join ', '
        PublicIP = $publicIP
    }
}
Set-Alias myip Get-MyIP

# --- Port Inspection (Single-pass process lookup) ---
function Get-ListeningPorts {
    $procs = @{}
    Get-Process | ForEach-Object { $procs[$_.Id] = $_.ProcessName }

    Get-NetTCPConnection -State Listen |
        Sort-Object LocalPort |
        Select-Object LocalAddress, LocalPort, OwningProcess, @{
            N = 'ProcessName'
            E = { $procs[[int]$_.OwningProcess] }
        }
}
Set-Alias ports Get-ListeningPorts

# --- Flush DNS ---
function Flush-Dns {
    Clear-DnsClientCache
    Write-Host "DNS Resolver Cache Flushed." -ForegroundColor Green
}

# --- Hardware Quick Checks ---
function Get-GpuStatus {
    if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        Write-Host "nvidia-smi not found in PATH." -ForegroundColor Red
        return
    }
    $parts = (nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv,noheader,nounits) -split ',\s*'
    [PSCustomObject]@{
        GPU      = $parts[0]
        Temp     = "$($parts[1]) °C"
        CoreLoad = "$($parts[2]) %"
        MemLoad  = "$($parts[3]) %"
        VRAM     = "$($parts[4]) / $($parts[5]) MiB"
        Power    = "$($parts[6]) W"
    }
}
Set-Alias gpu Get-GpuStatus

function Get-DiskHealth {
    Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, OperationalStatus, HealthStatus, Temperature
}
Set-Alias diskhealth Get-DiskHealth

# --- Editor Overrides ---
function Start-Notepad {
    $nppPath   = "${env:ProgramFiles}\Notepad++\notepad++.exe"
    $nppPath32 = "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"

    if (Test-Path $nppPath) {
        & $nppPath @args
    } elseif (Test-Path $nppPath32) {
        & $nppPath32 @args
    } else {
        notepad.exe @args
    }
}

Remove-Item alias:notepad -ErrorAction SilentlyContinue
Set-Alias -Name notepad -Value Start-Notepad -Option AllScope -Force

# --- Shell Navigation & Quick Utilities ---
function which {
    Get-Command @args -ErrorAction SilentlyContinue | Select-Object Name, CommandType, Source
}

function ep     { notepad $PROFILE }
function reload { . $PROFILE }

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    # Create first, then cd to its full path (avoids the $PWD provider-prefix quirk)
    $newDir = New-Item -ItemType Directory -Path $Path -Force
    Set-Location -LiteralPath $newDir.FullName
}


# List all custom commands, aliases, and descriptions from $PROFILE
function Get-ProfileCommands {
    param([string]$Filter)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($PROFILE, [ref]$tokens, [ref]$errors)

    # Map "# --- Section Name ---" headers
    $sections = $tokens | Where-Object {
        $_.Kind -eq 'Comment' -and $_.Text -match '^#\s*---\s*(.+?)\s*---$'
    } | ForEach-Object {
        [PSCustomObject]@{ Line = $_.Extent.StartLineNumber; Name = ($Matches[1] -replace '\s*\(.*\)$', '') }
    }

    # Map Set-Alias targets -> alias names
    $aliasMap = @{}
    $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Set-Alias'
    }, $true) | ForEach-Object {
        $elements = $_.CommandElements
        $name = $null; $val = $null
        for ($i = 1; $i -lt $elements.Count; $i++) {
            $txt = $elements[$i].ToString()
            if ($txt -eq '-Name' -and ($i + 1) -lt $elements.Count) {
                $name = $elements[++$i].ToString().Trim('"', "'")
            } elseif ($txt -eq '-Value' -and ($i + 1) -lt $elements.Count) {
                $val = $elements[++$i].ToString().Trim('"', "'")
            } elseif (-not $txt.StartsWith('-')) {
                if (-not $name) { $name = $txt.Trim('"', "'") }
                elseif (-not $val) { $val = $txt.Trim('"', "'") }
            }
        }
        if ($name -and $val) { $aliasMap[$val] += @($name) }
    }

    # Internal helpers to omit from the cheat sheet
    $excludedFuncs = @('Get-ProfileCommands', 'Test-IsAdmin', 'Get-WingetPending')

    # Collect profile functions + aliases
    $entries = [System.Collections.Generic.List[object]]::new()
    $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Parent -is [System.Management.Automation.Language.NamedBlockAst] -and
        $node.Parent.Parent -eq $ast -and
        $node.Name -notin $excludedFuncs
    }, $false) | ForEach-Object {
        $line = $_.Extent.StartLineNumber

        # Skip any future function marked with "# Helper: ..." directly above it
        $above = $tokens | Where-Object {
            $_.Kind -eq 'Comment' -and $_.Extent.EndLineNumber -eq ($line - 1)
        } | Select-Object -Last 1
        if ($above -and $above.Text -match '^#\s*Helper:') { return }

        $sec = ($sections | Where-Object { $_.Line -lt $line } | Select-Object -Last 1).Name
        if (-not $sec) { $sec = 'Shell & Utilities' }

        $aliases = $aliasMap[$_.Name]
        $entries.Add([PSCustomObject]@{
            Category = $sec
            Primary  = if ($aliases) { $aliases -join '/' } else { $_.Name }
            Target   = if ($aliases) { $_.Name } else { '' }
        })
    }

    # Everyday PowerShell, Zoxide & CLI essentials
    $commonCmds = @(
        @{ Category = 'Common Navigation'; Primary = 'z / zi';         Target = 'zoxide jump' }
        @{ Category = 'Common Navigation'; Primary = 'ii .';           Target = 'open Explorer' }
        @{ Category = 'Common Navigation'; Primary = 'Alt+.';          Target = 'yank last arg' }
        @{ Category = 'Common Navigation'; Primary = 'F2';             Target = 'prediction view' }
        @{ Category = 'Common PowerShell'; Primary = 'scb / gcb';      Target = 'set/get clipboard' }
        @{ Category = 'Common PowerShell'; Primary = 'sls';            Target = 'Select-String (grep)' }
        @{ Category = 'Common PowerShell'; Primary = 'Get-FileHash';   Target = 'SHA256 hash' }
        @{ Category = 'Common PowerShell'; Primary = 'sudo';           Target = 'run elevated' }
        @{ Category = 'Common Packages';   Primary = 'winget / choco'; Target = 'search / install' }
        @{ Category = 'Common Packages';   Primary = 'scoop';          Target = 'search / install' }
    )
    foreach ($c in $commonCmds) {
        $entries.Add([PSCustomObject]$c)
    }

    if ($Filter) {
        $pattern = [regex]::Escape($Filter)
        $entries = $entries | Where-Object {
            $_.Category -match $pattern -or $_.Primary -match $pattern -or $_.Target -match $pattern
        }
    }

    # Catppuccin Mocha ANSI colors
    $mauve = "`e[38;2;203;166;247m"
    $green = "`e[38;2;166;227;161m"
    $muted = "`e[38;2;108;112;134m"
    $reset = "`e[0m"

    $entries | Group-Object Category | ForEach-Object {
        $cat = $_.Name.PadRight(21)
        $items = $_.Group | ForEach-Object {
            if ($_.Target) {
                "$green$($_.Primary)$reset $muted($($_.Target))$reset"
            } else {
                "$green$($_.Primary)$reset"
            }
        }
        Write-Host "$mauve$cat$reset $($items -join ', ')"
    }
}
Set-Alias cmds Get-ProfileCommands

# ------------------------------------------------------------------------------
# 5. AUTO-COMPLETION & SMART NAVIGATION (Winget, Chocolatey, Zoxide)
# ------------------------------------------------------------------------------
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast  = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# Lazy-load Chocolatey completions on first 'choco' Tab press
if ($env:ChocolateyInstall -and (Test-Path "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1")) {
    Register-ArgumentCompleter -Native -CommandName choco -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        if (Test-Path $chocoProfile) {
            Import-Module $chocoProfile -Global
        }
        TabExpansion2 -inputScript $commandAst.ToString() -cursorColumn $cursorPosition |
            Select-Object -ExpandProperty CompletionMatches
    }
}

# Smart directory jumping (activates automatically if zoxide is installed)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ------------------------------------------------------------------------------
# 6. STARTUP TIMING & FASTFETCH EXECUTION
# ------------------------------------------------------------------------------
$loadMs = [math]::Round(((Get-Date) - (Get-Process -Id $PID).StartTime).TotalMilliseconds)
$env:PS_LOAD_TIME       = "${loadMs}ms"
$env:POWERSHELL_VERSION = $PSVersionTable.PSVersion.ToString()

fastfetch

Write-Host "Shell loaded in $loadMs ms" -ForegroundColor Blue

# ------------------------------------------------------------------------------
# 7. AUTO-UPDATE ON STARTUP (Once per day, interactive shells only)
# ------------------------------------------------------------------------------
$updateStamp   = "$env:TEMP\ps_last_update.txt"
$isInteractive = [Environment]::UserInteractive -and ($Host.Name -eq 'ConsoleHost')

if ($isInteractive -and (-not (Test-Path $updateStamp) -or ((Get-Item $updateStamp).LastWriteTime.Date -lt (Get-Date).Date))) {
    New-Item -Path $updateStamp -ItemType File -Force | Out-Null
    # Run the daily upgrade in its own elevated window so the prompt never blocks.
    # (UAC, if shown, belongs to that window. Zero-popup alternative: a scheduled task.)
    Write-Host "Daily package upgrade launched in a separate window." -ForegroundColor DarkGray
    Start-Process pwsh -Verb RunAs -WindowStyle Minimized -ArgumentList @(
        "-Command",
        "updateall; Read-Host Press-Enter-to-close"
    )
}
