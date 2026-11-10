<#
.SYNOPSIS
  Reproduce the PowerShell + Oh My Posh + Windows Terminal setup on a Windows PC.
  The counterpart of ./install.sh (macOS).

.DESCRIPTION
  Run from a PowerShell prompt (any version) in the cloned repo:  .\windows\install.ps1
  Every step is idempotent. Existing real files are never deleted - they are moved
  to <file>.bak-<timestamp> before being replaced.

.PARAMETER NoPackages
  Skip winget package installation.
.PARAMETER NoModules
  Skip PowerShell Gallery modules (PSReadLine, PSFzf).
.PARAMETER NoTerminal
  Skip the Windows Terminal profile.
.PARAMETER NoExtras
  Skip the packages marked "optional" in packages.json.
.PARAMETER ShellOnly
  Install only the interactive shell dependencies, not development applications.
#>
[CmdletBinding()]
param(
    [switch]$NoPackages,
    [switch]$NoModules,
    [switch]$NoTerminal,
    [switch]$NoExtras,
    [switch]$ShellOnly
)

$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
$Marker = '# zsh-config windows stub'

function Info($m) { Write-Host "==> $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host " ok $m" -ForegroundColor Green }
function Warn($m) { Write-Host " !! $m" -ForegroundColor Yellow }

if ($env:OS -ne 'Windows_NT') { Warn 'Windows only (use ./install.sh on macOS).'; exit 1 }

$config = Get-Content (Join-Path $Repo 'packages.json') -Raw | ConvertFrom-Json
$shellCommands = @{
    'Microsoft.PowerShell' = 'pwsh'
    'Git.Git' = 'git'
    'JanDeDobbeleer.OhMyPosh' = 'oh-my-posh'
    'junegunn.fzf' = 'fzf'
    'eza-community.eza' = 'eza'
    'ajeetdsouza.zoxide' = 'zoxide'
    'sharkdp.bat' = 'bat'
}
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')

# ------------------------------------------------------------------
# 1. Execution policy (profiles are scripts)
# ------------------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in 'Undefined', 'Restricted', 'AllSigned') {
    Info 'Setting the CurrentUser execution policy to RemoteSigned so the profile can load...'
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

# ------------------------------------------------------------------
# 2. Packages via winget
# ------------------------------------------------------------------
$failed = @()
if (-not $NoPackages) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Warn 'winget not found - install "App Installer" from the Microsoft Store, then re-run.'
    }
    else {
        Info 'Installing packages with winget...'
        foreach ($p in $config.packages) {
            if ($NoExtras -and $p.optional) { continue }
            if ($ShellOnly -and $p.id -notin @(
                'Microsoft.PowerShell', 'Git.Git', 'JanDeDobbeleer.OhMyPosh',
                'junegunn.fzf', 'eza-community.eza', 'ajeetdsouza.zoxide',
                'sharkdp.bat', 'DEVCOM.JetBrainsMonoNerdFont'
            )) { continue }
            if ($p.id -eq 'DEVCOM.JetBrainsMonoNerdFont') {
                try { & (Join-Path $Repo 'install-font.ps1'); Ok $p.name }
                catch { Warn $_.Exception.Message; $failed += $p.name }
                continue
            }
            if ($shellCommands.ContainsKey($p.id) -and (Get-Command $shellCommands[$p.id] -ErrorAction SilentlyContinue)) {
                Ok "$($p.name) (already available)"
                continue
            }
            winget list --id $p.id --exact --accept-source-agreements *> $null
            if ($LASTEXITCODE -eq 0) { Ok "$($p.name) (already installed)"; continue }
            winget install --id $p.id --exact --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) { Ok $p.name } else { Warn "could not install $($p.name) ($($p.id))"; $failed += $p.name }
        }
    }
}

# ------------------------------------------------------------------
# 3. PowerShell modules
# ------------------------------------------------------------------
if (-not $NoModules) {
    Info 'Installing PowerShell modules (CurrentUser scope)...'
    foreach ($m in $config.modules) {
        try {
            if (Get-Module -ListAvailable $m.name | Where-Object { $_.Version -ge [version]$m.minimumVersion }) {
                Ok "$($m.name) (already installed)"
                continue
            }
            Install-Module -Name $m.name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
            Ok $m.name
        }
        catch { Warn "could not install module $($m.name): $($_.Exception.Message)"; $failed += $m.name }
    }
}

# ------------------------------------------------------------------
# 4. Profile stubs: one line that dot-sources windows\profile.ps1
# ------------------------------------------------------------------
Info 'Linking the PowerShell profile...'
$docs = [Environment]::GetFolderPath('MyDocuments')
$stub = "$Marker`n. '$(Join-Path $Repo 'profile.ps1')'`n"
foreach ($dir in 'PowerShell') {
    $target = Join-Path $docs "$dir\profile.ps1"
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    if ((Test-Path $target) -and -not (Select-String -Path $target -SimpleMatch $Marker -Quiet)) {
        Move-Item $target "$target.bak-$Stamp"
        Warn "backed up existing profile to $target.bak-$Stamp"
    }
    Set-Content -Path $target -Value $stub -Encoding UTF8
    Ok $target
}

# Host-specific profiles load after profile.ps1 and otherwise override its keys
# and aliases. Preserve the old file, but leave customization in local.ps1.
$hostProfile = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
if ((Test-Path $hostProfile) -and -not (Select-String -Path $hostProfile -SimpleMatch $Marker -Quiet)) {
    Move-Item $hostProfile "$hostProfile.bak-$Stamp"
    Warn "backed up host profile to $hostProfile.bak-$Stamp"
}
Set-Content -Path $hostProfile -Value "$Marker`n# Setup is loaded by profile.ps1; put overrides in windows\local.ps1." -Encoding UTF8

# ------------------------------------------------------------------
# 5. Machine-local overrides (gitignored)
# ------------------------------------------------------------------
$local = Join-Path $Repo 'local.ps1'
if (-not (Test-Path $local)) {
    Copy-Item (Join-Path $Repo 'local.ps1.example') $local
    Ok 'seeded local.ps1 (machine-specific, not tracked)'
}

# ------------------------------------------------------------------
# 6. Windows Terminal profile (JSON fragment)
# ------------------------------------------------------------------
if (-not $NoTerminal) {
    Info 'Adding the chaf-dynamic Windows Terminal profile...'
    $fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\zsh-config'
    New-Item -ItemType Directory -Force -Path $fragDir | Out-Null
    Copy-Item (Join-Path $Repo 'terminal\chaf-dynamic.json') $fragDir -Force
    Ok "fragment installed: $fragDir"
    Warn 'Open Windows Terminal > Settings > Startup and pick "chaf-dynamic" as the default profile.'
    Warn 'Scroll key bindings: paste terminal\actions.snippet.jsonc into settings.json "actions".'
}

# ------------------------------------------------------------------
# 7. Verify every runtime dependency
# ------------------------------------------------------------------
Info 'Verifying (new tools may need a fresh terminal to show up on PATH)...'
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
$commands = @('pwsh', 'git', 'oh-my-posh', 'fzf', 'eza', 'zoxide', 'bat')
if (-not $ShellOnly) { $commands += 'gh', 'code' }
foreach ($cmd in $commands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { Ok $cmd } else { Warn "missing: $cmd" }
}
foreach ($m in $config.modules) {
    if (Get-Module -ListAvailable $m.name) { Ok "module $($m.name)" } else { Warn "missing module: $($m.name)" }
}
if (-not (Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'JetBrainsMono*' -ErrorAction SilentlyContinue)) {
    Warn 'JetBrainsMono Nerd Font not found - prompt icons will render as boxes.'
}

if ($failed) { Warn "Not installed: $($failed -join ', ')" }
Write-Host "`nDone. Close and reopen Windows Terminal (use the chaf-dynamic profile)." -ForegroundColor Green
