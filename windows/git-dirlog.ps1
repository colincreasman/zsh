# git-dirlog.ps1 - PowerShell port of zsh/git-dirlog.sh.
# glog-dir: show the most recent commits that touched a folder on main.
#
# Set GLOG_DIR_REPO to a repo path to make it the default target, e.g.
#   $env:GLOG_DIR_REPO = "$HOME\Personal\Repos\kbd\forager\firmware"

# git accepts a lot of date input but silently misreads some of it ("last 7 days"
# -> 30 days ago, "3d" -> 21 days ago), so rewrite those shapes first.
function ConvertTo-GlogDate {
    param([string]$Text)
    $s = $Text.Trim().ToLower()
    $s = $s -replace '^(the )?(last|past|previous)\s+(?=\d)', ''
    $units = [ordered]@{
        'seconds' = 's|sec|secs|second|seconds'; 'minutes' = 'min|mins|minute|minutes'
        'hours'   = 'h|hr|hrs|hour|hours';       'days'    = 'd|day|days'
        'weeks'   = 'w|wk|wks|week|weeks';       'months'  = 'm|mo|mon|month|months'
        'years'   = 'y|yr|yrs|year|years'
    }
    foreach ($u in $units.GetEnumerator()) {
        if ($s -match "^(\d+)\s*($($u.Value))$") { return "$($Matches[1]) $($u.Key) ago" }
    }
    if ($s -match '^\d+\s+(second|minute|hour|day|week|month|year)s?$') { return "$s ago" }
    $s
}

# git resolves unparseable dates to "now" instead of erroring; reject that
# unless the user really meant now.
function Test-GlogDate {
    param([string]$Root, [string]$Raw, [string]$Value)
    if ($Value -match '^(now|today)$|just now') { return $true }
    $epoch = (git -C $Root rev-parse "--since=$Value" 2>$null) -replace '^--max-age=', ''
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($epoch -match '^\d+$' -and [long]$epoch -ge ($now - 2)) {
        [Console]::Error.WriteLine("glog-dir: could not understand the date '$Raw'")
        [Console]::Error.WriteLine("         try '7 days ago', 'last 2 weeks', 'yesterday' or '2026-01-01'")
        return $false
    }
    $true
}

function glog-dir {
    $count = 15
    $repo = if ($env:GLOG_DIR_REPO) { $env:GLOG_DIR_REPO } else { '.' }
    $branch = ''
    $fetch = $true
    $files = $false
    $path = ''
    $extra = @()
    $bound = @{ lo = @{ raw = ''; incl = $true }; hi = @{ raw = ''; incl = $true } }

    $i = 0
    while ($i -lt $args.Count) {
        $a = [string]$args[$i]
        $eq = $a -match '^(--[a-z-]+)=(.*)$'
        $name = if ($eq) { $Matches[1] } else { $a }
        $val = if ($eq) { $Matches[2] } else { $null }
        $v = if ($eq) { $val } elseif ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { '' }
        $step = if ($eq) { 1 } else { 2 }
        switch -CaseSensitive -Regex ($name) {
            '^(-n|--max-count)$' { $count = [int]$v; $i += $step; continue }
            '^-n\d+$' { $count = [int]$name.Substring(2); $i++; continue }
            '^(-C|--repo)$' { $repo = $v; $i += $step; continue }
            '^(-b|--branch)$' { $branch = $v; $i += $step; continue }
            '^(-s|--since)$' { $bound.lo = @{ raw = $v; incl = $true }; $i += $step; continue }
            '^--after$' { $bound.lo = @{ raw = $v; incl = $false }; $i += $step; continue }
            '^(-u|--until)$' { $bound.hi = @{ raw = $v; incl = $true }; $i += $step; continue }
            '^--before$' { $bound.hi = @{ raw = $v; incl = $false }; $i += $step; continue }
            '^(-F|--fetch)$' { $fetch = $true; $i++; continue }
            '^(-N|--no-fetch)$' { $fetch = $false; $i++; continue }
            '^(-f|--files)$' { $files = $true; $i++; continue }
            '^(-h|--help)$' {
                @'
glog-dir [options] <folder> [-- <extra git log args>]

Show the most recent commits touching <folder> on the repo's main branch.

  -n N, --max-count N   number of commits to show (default: 15)
  -C DIR, --repo DIR    repository to query (default: $env:GLOG_DIR_REPO or cwd)
  -b REF, --branch REF  branch to inspect (default: auto-detect main/master)
  -N, --no-fetch        skip the `git fetch` refresh of the remote ref
  -F, --fetch           force the fetch (default when a remote ref is used)
  -f, --files           list the files each commit changed under <folder>
  -h, --help            show this help

Time bounds - each takes either a fuzzy date or a commit-ish on the branch:
  -s, --since VALUE     lower bound, inclusive of a named commit
      --after VALUE     lower bound, exclusive of a named commit
  -u, --until VALUE     upper bound, inclusive of a named commit
      --before VALUE    upper bound, exclusive of a named commit

  Dates are fuzzy: "last 7 days", "7 days ago", "3d", "2w", "6h", "yesterday",
  "last monday", "2 months", "2026-01-01", "Jan 1 2026". Unparseable dates are
  rejected rather than silently treated as "now".

Examples:
  glog-dir src/api
  glog-dir -n 40 -C ~/Personal/Repos/kbd/forager/firmware config
  glog-dir --since='last 7 days' src/api
  glog-dir --after=9f2c1ab --until=yesterday docs
  glog-dir docs -- --author=alice
'@
                return
            }
            '^--$' { $extra = @($args | Select-Object -Skip ($i + 1)); $i = $args.Count; continue }
            '^-' {
                # PowerShell swallows a bare `--`, so anything unknown after <folder> goes to git log.
                if ($path) { $extra = @($args | Select-Object -Skip $i); $i = $args.Count; continue }
                [Console]::Error.WriteLine("glog-dir: unknown option: $a"); return
            }
            default {
                if (-not $path) { $path = $a; $i++ }
                else { $extra = @($args | Select-Object -Skip $i); $i = $args.Count }
                continue
            }
        }
    }

    if (-not $path) { [Console]::Error.WriteLine('glog-dir: missing <folder>. Try `glog-dir --help`.'); return }

    $root = git -C $repo rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) { [Console]::Error.WriteLine("glog-dir: not a git repository: $repo"); return }

    $ref = $branch
    if (-not $ref) {
        foreach ($try in 'origin/main', 'origin/master', 'main', 'master') {
            git -C $root rev-parse --verify --quiet $try *> $null
            if ($LASTEXITCODE -eq 0) { $ref = $try; break }
        }
        if (-not $ref) { [Console]::Error.WriteLine("glog-dir: could not find a main/master branch in $root"); return }
    }

    # A stale local clone would otherwise report an out-of-date "latest".
    if ($fetch -and $ref -match '/') {
        $remote, $remoteRef = $ref -split '/', 2
        git -C $root fetch --quiet $remote $remoteRef 2>$null
        if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("glog-dir: fetch failed, showing cached $ref") }
    }

    # A bound is a commit if it has no spaces and the repo can resolve it; else a date.
    $commit = @{}
    $date = @{}
    foreach ($side in 'lo', 'hi') {
        $raw = $bound[$side].raw
        if (-not $raw) { continue }
        $isRev = $false
        if ($raw -notmatch '\s') {
            git -C $root rev-parse --verify --quiet "$raw^{commit}" *> $null
            $isRev = ($LASTEXITCODE -eq 0)
        }
        if ($isRev) {
            git -C $root merge-base --is-ancestor $raw $ref 2>$null
            if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("glog-dir: warning: $raw is not on $ref") }
            $commit[$side] = $raw
        }
        else {
            $norm = ConvertTo-GlogDate $raw
            if (-not (Test-GlogDate $root $raw $norm)) { return }
            $date[$side] = $norm
        }
    }

    # Commit bounds become a real revision range; date bounds stay as flags.
    $range = $ref
    if ($commit.hi) { $range = if ($bound.hi.incl) { $commit.hi } else { "$($commit.hi)^" } }
    if ($commit.lo) {
        $start = $commit.lo
        if ($bound.lo.incl) {
            git -C $root rev-parse --verify --quiet "$($commit.lo)^" *> $null
            if ($LASTEXITCODE -eq 0) { $start = "$($commit.lo)^" }
        }
        $range = "$start..$range"
    }

    # Absolutize so the pathspec means what the user sees, since git -C makes
    # the repo root the cwd. Try the caller's cwd first, then the repo directory.
    $target = $path
    foreach ($base in '.', $repo) {
        $candidate = Join-Path $base $path
        if (Test-Path -LiteralPath $candidate) {
            $abs = (Resolve-Path -LiteralPath $candidate).ProviderPath
            if ($abs.StartsWith($root.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) { $target = $abs; break }
        }
    }

    $logArgs = @($range, "--max-count=$count", '--date=short', '--color=always',
                 '--pretty=format:%C(auto)%h%Creset %C(dim)%ad%Creset %C(bold blue)%an%Creset %s')
    if ($files) { $logArgs += '--name-only' }
    if ($date.lo) { $logArgs += "--since=$($date.lo)" }
    if ($date.hi) { $logArgs += "--until=$($date.hi)" }
    $logArgs += $extra

    $out = git -C $root log @logArgs -- $target
    if ($LASTEXITCODE -ne 0) { return }
    if ($out) { $out; return }

    # Distinguish "nothing in this time window" from "that path isn't tracked".
    $any = git -C $root log $ref --max-count=1 --format=%h -- $target 2>$null
    if ($any) { [Console]::Error.WriteLine("glog-dir: no commits touching $path on $ref in that range") }
    else { [Console]::Error.WriteLine("glog-dir: no commits touching $path on $ref (is it tracked? repo root is $root)") }
}
