# profile.ps1 - the PowerShell twin of home/.zshrc.
# $PROFILE.CurrentUserAllHosts is a one-line stub (written by install.ps1) that
# dot-sources this file, so the repo can live anywhere and editing it here is
# editing your live profile.

# ~~~~~~~~~~~~~~~~~~ Locate this repo ~~~~~~~~~~~~~~~~~~~
$env:WIN_CONFIG = $PSScriptRoot
$env:ZSH_CONFIG = Split-Path $PSScriptRoot -Parent

# ~~~~~~~~~~~~~~~~~~ Env vars ~~~~~~~~~~~~~~~~~~~
$env:LS_COLORS = 'di=1:fi=96:*.m=31:*.py=32:*.txt=36:*.out=35'
# Copilot CLI Ctrl+G: `code` returns immediately, so block until the tab closes
$env:COPILOT_EDITOR = 'code --wait'
$env:EDITOR = 'code --wait'
$env:REPOS = Split-Path $env:ZSH_CONFIG -Parent
$env:KBD = Join-Path $env:REPOS 'kbd'

# ~~~~~~~~~~~~~~~~~~ PATH ~~~~~~~~~~~~~~~~~~~
# Only add entries that actually exist, so a fresh PC missing one of these
# doesn't end up with a PATH full of dead directories.
function Add-PathEntry {
    param([string]$Dir, [switch]$Append)
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return }
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and ($_ -ne $Dir) })
    $env:PATH = if ($Append) { (@($parts) + $Dir) -join ';' } else { (@($Dir) + $parts) -join ';' }
}

Add-PathEntry (Join-Path $HOME '.local\bin')
Add-PathEntry (Join-Path $HOME '.cargo\bin')
Add-PathEntry 'C:\Program Files\mosquitto' -Append
Add-PathEntry 'C:\Program Files\Sublime Merge' -Append

# ~~~~~~~~~~~~~~~~~~ Java / Android ~~~~~~~~~~~~~~~~~~~
$jdk = Get-ChildItem 'C:\Program Files\Microsoft\jdk-21*' -ErrorAction SilentlyContinue |
    Where-Object PSIsContainer | Sort-Object Name -Descending | Select-Object -First 1
if ($jdk) { $env:JAVA_HOME = $jdk.FullName; Add-PathEntry (Join-Path $jdk.FullName 'bin') }
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
if (Test-Path $androidSdk) {
    $env:ANDROID_HOME = $androidSdk
    Add-PathEntry (Join-Path $androidSdk 'platform-tools')
}

# ~~~~~~~~~~~~~~~~~~ Dotfiles ~~~~~~~~~~~~~~~~~~~
. (Join-Path $PSScriptRoot 'aliases.ps1')
. (Join-Path $PSScriptRoot 'functions.ps1')
. (Join-Path $PSScriptRoot 'git-dirlog.ps1')

pyinit

# Everything below needs a real console; skip it for `pwsh -Command ...` runs.
if ($Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
    -not ([Environment]::GetCommandLineArgs() -match '^-(Command|c|EncodedCommand|e|File|f|NonInteractive)$')) {

    # ~~~~~~~~~~~~~~~~~~ Prompt (Powerlevel10k -> Oh My Posh) ~~~~~~~~~~~~~~~~~~~
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config (Join-Path $PSScriptRoot 'chaf.omp.json') | Invoke-Expression
    }

    # ~~~~~~~~~~~~~~~~~~ Z (zsh-z -> zoxide) ~~~~~~~~~~~~~~~~~~~
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }

    # ~~~~~~~~~~~~~~~~~~ Autosuggest, highlighting, key bindings, fzf ~~~~~~~~~~~~~~~~~~~
    . (Join-Path $PSScriptRoot 'keybindings.ps1')
    Set-ShellKeyBindings
    Initialize-Completions
}

# ~~~~~~~~~~~~~~~~~~ Machine-local overrides ~~~~~~~~~~~~~~~~~~~
# Not tracked in git: work paths, proxies, secrets, per-machine SDKs.
$localConfig = Join-Path $PSScriptRoot 'local.ps1'
if (Test-Path $localConfig) { . $localConfig }
