# functions.ps1 - the PowerShell twin of zsh/functions.zsh (non-ZLE parts).
# Key bindings and completion previews live in keybindings.ps1.

# ~~~~~~~~~~~~~~~~~~ Functions[Git] ~~~~~~~~~~~~~~~~~~~
function Get-MainBranch {
    if (-not $env:MAIN) {
        $env:MAIN = (git remote show origin | Select-String 'HEAD branch').Line.Trim().Split()[-1]
    }
    $env:MAIN
}

function grbours { param([string]$Path) git checkout --ours -- $Path; git add $Path }
function grbtheirs { param([string]$Path) git checkout --theirs -- $Path; git add $Path }
function grbog { git rebase --no-verify -i -- "origin/$(Get-MainBranch)" }
function gcfog { param([string]$Path) git checkout --no-overlay --force "origin/$(Get-MainBranch)" -- $Path }
function grsog { git reset --hard "origin/$(Get-MainBranch)" }

# Print the 8-char short form of a commit hash and copy it to the clipboard.
# Accepts a full/partial hex hash, or any ref when run inside a git repo.
function ghash {
    param([Parameter(Mandatory, Position = 0)][string]$Hash)
    if ($Hash -notmatch '^[0-9a-fA-F]{8,}$') {
        $resolved = git rev-parse --verify --quiet "$Hash^{commit}"
        if ($LASTEXITCODE -ne 0 -or -not $resolved) {
            Write-Error "ghash: '$Hash' is not a hash or resolvable ref"
            return
        }
        $Hash = $resolved
    }
    $short = $Hash.Substring(0, 8).ToLower()
    Set-Clipboard -Value $short
    $short
}

# ~~~~~~~~~~~~~~~~~~ Functions[PS] ~~~~~~~~~~~~~~~~~~~
function psls {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    Get-Process | Where-Object { $_.ProcessName -like "*$Name*" } |
        Select-Object Id, ProcessName, CPU, WS, StartTime
}

function pskill {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    $procs = @(Get-Process | Where-Object { $_.ProcessName -like "*$Name*" -and $_.Id -ne $PID })
    Write-Host "`nSearching for '$Name' -- Found $($procs.Count) Running Processes .. "
    $procs | Format-Table Id, ProcessName -AutoSize
    Write-Host "`nTerminating $($procs.Count) processes .. "
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Done!`n`nRunning search again:"
    psls $Name
}

function unsetproxies {
    foreach ($v in 'http_proxy', 'https_proxy', 'no_proxy', 'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY') {
        Remove-Item "Env:$v" -ErrorAction SilentlyContinue
    }
}

# ~~~~~~~~~~~~~~~~~~ Python ~~~~~~~~~~~~~~~~~~~
function pyinit {
    $pyenvWin = Join-Path $HOME '.pyenv\pyenv-win'
    if (Test-Path $pyenvWin) {
        $env:PYENV = $pyenvWin + '\'
        $env:PYENV_ROOT = $env:PYENV
        $env:PYENV_HOME = $env:PYENV
        Add-PathEntry (Join-Path $pyenvWin 'shims')
        Add-PathEntry (Join-Path $pyenvWin 'bin')
    }
}

# ~~~~~~~~~~~~~~~~~~ Colors ~~~~~~~~~~~~~~~~~~~
# Print the 256-color palette (the `lscolors` of the Mac).
function lscolors {
    $esc = [char]27
    foreach ($i in 0..255) {
        Write-Host -NoNewline ("{0}[48;5;{1}m  {0}[0m{0}[38;5;{1}m{1,3}{0}[0m " -f $esc, $i)
        if ($i % 6 -eq 3) { Write-Host }
    }
    Write-Host
}
