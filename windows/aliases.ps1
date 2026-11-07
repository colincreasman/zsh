# aliases.ps1 - the PowerShell twin of zsh/aliases.zsh.
# PowerShell aliases can't take arguments, so every "alias" here is a function.
# Command names are case-insensitive, so the two that collided on the Mac
# (gcM/gcm, grbC/grbc) are renamed: see the notes next to them.

# Functions lose to built-in aliases of the same name, so drop the ones we shadow.
foreach ($name in 'gc', 'gcm', 'ls') {
    Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue
}

# ~~~~~~~~~~~~~~~~~~ Aliases[Config] ~~~~~~~~~~~~~~~~~~~
# `z,` `a,` `f,` `l,` can't be PowerShell names (the comma), so: ez ea ef el ep
function Edit-Config {
    $editor = if (Get-Command code -ErrorAction SilentlyContinue) { 'code' } else { 'notepad' }
    & $editor @args
}
function ep { Edit-Config (Join-Path $env:WIN_CONFIG 'profile.ps1') }    # z,
function ea { Edit-Config (Join-Path $env:WIN_CONFIG 'aliases.ps1') }    # a,
function ef { Edit-Config (Join-Path $env:WIN_CONFIG 'functions.ps1') }  # f,
function el { Edit-Config (Join-Path $env:WIN_CONFIG 'local.ps1') }      # l,
function ek { Edit-Config (Join-Path $env:WIN_CONFIG 'keybindings.ps1') }
function zc { Set-Location $env:ZSH_CONFIG }

# ~~~~~~~~~~~~~~~~~~ Aliases[Misc] ~~~~~~~~~~~~~~~~~~~
function cpwd { (Get-Location).Path | Set-Clipboard }                    # copy cwd
function cpl { (Get-History -Count 1).CommandLine | Set-Clipboard }      # copy last command
function cpo { Invoke-Expression (Get-History -Count 1).CommandLine | Out-String | Set-Clipboard }  # copy last output
function pb { $input | Set-Clipboard }                                   # pbcopy
function pbp { Get-Clipboard }                                           # pbpaste
function o { Invoke-Item @args }                                         # open with default app
function src { & (Get-Process -Id $PID).Path -NoLogo; exit }             # reload (like `exec zsh`)

# Toggle Windows dark/light mode (the `swbg` of the Mac)
function swbg {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $light = [int](-not (Get-ItemPropertyValue $key AppsUseLightTheme))
    Set-ItemProperty $key AppsUseLightTheme $light
    Set-ItemProperty $key SystemUsesLightTheme $light
}

# ~~~~~~~~~~~~~~~~~~ Aliases[Locations] ~~~~~~~~~~~~~~~~~~~
function hh { Set-Location (git rev-parse --show-toplevel) }
function hhh { Set-Location $HOME }

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function ..... { Set-Location ..\..\..\.. }

function data { Set-Location (Join-Path $HOME 'Data') }
function docs { Set-Location ([Environment]::GetFolderPath('MyDocuments')) }
function down { Set-Location (Join-Path $HOME 'Downloads') }
function desk { Set-Location ([Environment]::GetFolderPath('Desktop')) }
function apps { Set-Location 'C:\Program Files' }

function repos { Set-Location $env:REPOS }
function kbd { Set-Location $env:KBD }
function cokbd { code $env:KBD }

# ~~~~~~~~~~~~~~~~~~ Aliases[ls/Eza] ~~~~~~~~~~~~~~~~~~~
if (Get-Command eza -ErrorAction SilentlyContinue) {
    # Base eza command with preferred options
    function _eza {
        eza --all --group-directories-first --no-user --no-permissions `
            --classify --dereference --smart-group '--time-style=+%D - %I:%M%p' `
            --icons=always --color=always --color-scale=age --color-scale-mode=fixed @args
    }
    function ls { _eza @args }
    function la { _eza -1Alh --bytes @args }                       # long listing, header, sizes
    function ll { la --total-size --sort=size @args }              # by size (SLOW)
    function lr { la --recurse --tree @args }                      # tree (SLOW)
    function llr { ll --recurse --tree --sort=size @args }         # sized tree (VERY SLOW)
    function lt { la --modified --created --accessed @args }       # all time columns
    function lta { lt --sort=accessed @args }
    function ltc { lt --sort=created @args }
    function ltm { lt --sort=modified @args }
}
else {
    function ls { Get-ChildItem -Force @args }
    function la { Get-ChildItem -Force @args | Format-Table Mode, LastWriteTime, Length, Name }
}

# ~~~~~~~~~~~~~~~~~~ Aliases[Git] ~~~~~~~~~~~~~~~~~~~
function gc { git checkout @args }
function gbr { git branch --no-ignore-case @args }

function gs { git status --untracked-files -M --show-stash @args }
function gf { git fetch --prune @args }
# Fix "cannot lock ref" fetch errors: pack refs, delete the offending remote-tracking refs, re-fetch
function gfrs {
    git pack-refs --all --prune
    $out = git fetch origin 2>&1 | Out-String
    [regex]::Matches($out, "refs/remotes/origin/[^']+(?=')") | ForEach-Object { git update-ref -d $_.Value }
    git fetch origin
}

function grev { git rev-parse HEAD | Set-Clipboard }                 # copy current commit hash

function ga { git add @args }
function gaa { git add --all (git rev-parse --show-toplevel) }       # add everything possible

function grm { git restore --staged --worktree --no-overlay @args }  # discard changes to tracked paths
# Remove EVERYTHING `git status` shows (use with caution): staged/unstaged changes, untracked files,
# nested repos and dirty submodules. Ignored files and stashes are kept.
function gcls {
    git reset --hard --no-recurse-submodules
    git clean -ffd :/
    git submodule --quiet update --checkout --force --recursive
    git submodule --quiet foreach --recursive 'git clean -ffdq'
    gs
}

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Commit] ~~~~~~~~~~~~~~~~~~~
function gcnv { git commit --no-verify @args }   # Mac `gcM` (case-insensitive clash with gcm)
function gcm { git commit --no-verify -m @args } # commit with message
function gcam { gaa; git commit --no-verify -m @args }  # add everything and commit

function gfq { git commit --no-verify --amend --no-edit }  # fixup previous commit
function gfaq { gaa; gfq }                                 # fixup everything into previous commit

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Checkout] ~~~~~~~~~~~~~~~~~~~
function gcf { git checkout --no-overlay --force @args }
function gcfme { git checkout --no-overlay --force '@{u}' -- @args }

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Reset] ~~~~~~~~~~~~~~~~~~~
function grs { git reset --hard @args }
function grsme { git reset --hard '@{u}' }

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Rebase] ~~~~~~~~~~~~~~~~~~~
function grb { git rebase --no-verify -i @args }
function grba { git rebase --abort }
function grbq { git rebase --quit }
function grbs { git rebase --skip }
function grbc { git rebase --continue }
function grbac { git commit --amend --no-edit --no-verify; git rebase --continue }  # Mac `grbC`
function grbme { git rebase -i --no-verify '@{u}' }

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Push] ~~~~~~~~~~~~~~~~~~~
function gpsh { git push --no-verify @args }
function gfpsh { git push --no-verify --force-with-lease @args }
function gffpsh { git push --no-verify --force-with-lease --force @args }

# ~~~~~~~~~~~~~~~~~~ Aliases[Python] ~~~~~~~~~~~~~~~~~~~
function ipy { ipython --quick --profile=custom @args }

# glog-dir shortcuts (see git-dirlog.ps1)
function gld { glog-dir @args }
function gldf { glog-dir --files @args }
