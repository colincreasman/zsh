# shellcheck shell=sh
# glog-dir — show the most recent commits that touched a folder on main.
# POSIX-compatible so it can be sourced from both zsh and bash.
# Sourced by zsh-config/home/.zshrc and home/.bashrc (both symlinked into ~).
#
# Set GLOG_DIR_REPO to a repo path to make it the default target, e.g.
#   export GLOG_DIR_REPO=~/Repos/kbd/forager/firmware

# Normalize a fuzzy time expression into something git's approxidate parses
# correctly. git accepts a lot of input but silently misreads some of it:
#   "last 7 days" -> 30 days ago,  "3d" -> 21 days ago,  "2w" -> 22 days ago
# so we rewrite those shapes before handing them over.
_glog_dir_norm_date() {
    _gdn=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')

    # "last 7 days" / "past 2 weeks" / "the last 3 months" -> "7 days ago"
    _gdn=$(printf '%s' "$_gdn" | sed -E 's/^(the )?(last|past|previous) +([0-9])/\3/')

    # "3d" / "2 w" / "6hrs" -> "3 days ago" etc.
    _gdn=$(printf '%s' "$_gdn" | sed -E '
        s/^([0-9]+) *(s|sec|secs|second|seconds)$/\1 seconds ago/;
        s/^([0-9]+) *(min|mins|minute|minutes)$/\1 minutes ago/;
        s/^([0-9]+) *(h|hr|hrs|hour|hours)$/\1 hours ago/;
        s/^([0-9]+) *(d|day|days)$/\1 days ago/;
        s/^([0-9]+) *(w|wk|wks|week|weeks)$/\1 weeks ago/;
        s/^([0-9]+) *(m|mo|mon|month|months)$/\1 months ago/;
        s/^([0-9]+) *(y|yr|yrs|year|years)$/\1 years ago/;
    ')

    # A bare "7 days" still needs the "ago" suffix to be relative.
    _gdn=$(printf '%s' "$_gdn" | sed -E 's/^([0-9]+ +(second|minute|hour|day|week|month|year)s?)$/\1 ago/')

    printf '%s' "$_gdn"
}

# git resolves unparseable dates to "now" instead of erroring, which silently
# returns the wrong commits. Reject that unless the user really meant now.
_glog_dir_check_date() {
    _gdc_root=$1
    _gdc_raw=$2
    _gdc_val=$3
    # rev-parse --since only works inside a repo, hence the explicit -C.
    _gdc_epoch=$(git -C "$_gdc_root" rev-parse --since="$_gdc_val" 2>/dev/null)
    _gdc_epoch=${_gdc_epoch#--max-age=}
    _gdc_now=$(date +%s)

    case "$_gdc_val" in
        now|today|*just\ now*) return 0 ;;
    esac
    if [ -n "$_gdc_epoch" ] && [ "$_gdc_epoch" -ge "$((_gdc_now - 2))" ]; then
        printf 'glog-dir: could not understand the date %s\n' "'$_gdc_raw'" >&2
        printf "         try '7 days ago', 'last 2 weeks', 'yesterday' or '2026-01-01'\n" >&2
        return 1
    fi
    return 0
}

glog-dir() {
    _gd_count=15
    _gd_repo=${GLOG_DIR_REPO:-.}
    _gd_branch=
    _gd_fetch=1
    _gd_files=0
    _gd_path=
    _gd_lo= _gd_lo_raw= _gd_lo_incl=1
    _gd_hi= _gd_hi_raw= _gd_hi_incl=1

    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--max-count) _gd_count=$2; shift 2 ;;
            -n*)            _gd_count=${1#-n}; shift ;;
            -C|--repo)      _gd_repo=$2; shift 2 ;;
            --repo=*)       _gd_repo=${1#*=}; shift ;;
            -b|--branch)    _gd_branch=$2; shift 2 ;;
            --branch=*)     _gd_branch=${1#*=}; shift ;;

            -s|--since)     _gd_lo_raw=$2; _gd_lo_incl=1; shift 2 ;;
            --since=*)      _gd_lo_raw=${1#*=}; _gd_lo_incl=1; shift ;;
            --after)        _gd_lo_raw=$2; _gd_lo_incl=0; shift 2 ;;
            --after=*)      _gd_lo_raw=${1#*=}; _gd_lo_incl=0; shift ;;

            -u|--until)     _gd_hi_raw=$2; _gd_hi_incl=1; shift 2 ;;
            --until=*)      _gd_hi_raw=${1#*=}; _gd_hi_incl=1; shift ;;
            --before)       _gd_hi_raw=$2; _gd_hi_incl=0; shift 2 ;;
            --before=*)     _gd_hi_raw=${1#*=}; _gd_hi_incl=0; shift ;;

            -F|--fetch)     _gd_fetch=1; shift ;;
            -N|--no-fetch)  _gd_fetch=0; shift ;;
            -f|--files)     _gd_files=1; shift ;;
            -h|--help)
                cat <<'EOF'
glog-dir [options] <folder> [-- <extra git log args>]

Show the most recent commits touching <folder> on the repo's main branch.

  -n N, --max-count N   number of commits to show (default: 15)
  -C DIR, --repo DIR    repository to query (default: $GLOG_DIR_REPO or cwd)
  -b REF, --branch REF  branch to inspect (default: auto-detect main/master)
  -N, --no-fetch        skip the `git fetch` refresh of the remote ref
  -F, --fetch           force the fetch (default when a remote ref is used)
  -f, --files           list the files each commit changed under <folder>
  -h, --help            show this help

Time bounds -- each takes either a fuzzy date or a commit-ish on the branch:
  -s, --since VALUE     lower bound, inclusive of a named commit
      --after VALUE     lower bound, exclusive of a named commit
  -u, --until VALUE     upper bound, inclusive of a named commit
      --before VALUE    upper bound, exclusive of a named commit

  Dates are fuzzy: "last 7 days", "7 days ago", "3d", "2w", "6h",
  "yesterday", "last monday", "2 months", "2026-01-01", "Jan 1 2026".
  Shorthand months are m/mo/mon; minutes are min/mins. Unparseable dates
  are rejected rather than silently treated as "now".

  Commit bounds accept any rev (hash, tag, v1.2.0~3) and are applied as a
  true revision range rather than a date approximation.

Examples:
  glog-dir src/api
  glog-dir -n 40 -C ~/Repos/kbd/forager/firmware config
  glog-dir --since='last 7 days' src/api
  glog-dir --after=9f2c1ab --until=yesterday docs
  glog-dir --since=v1.4.0 --before=v1.5.0 -f src/api
  glog-dir docs -- --author=alice
EOF
                return 0 ;;
            --) shift; break ;;
            -*) printf 'glog-dir: unknown option: %s\n' "$1" >&2; return 2 ;;
            *)
                if [ -z "$_gd_path" ]; then _gd_path=$1; shift
                else break
                fi ;;
        esac
    done

    if [ -z "$_gd_path" ]; then
        printf 'glog-dir: missing <folder>. Try `glog-dir --help`.\n' >&2
        return 2
    fi

    # Resolve the repo root so <folder> can be given relative to the repo
    # regardless of the directory the command is invoked from.
    _gd_root=$(git -C "$_gd_repo" rev-parse --show-toplevel 2>/dev/null) || {
        printf 'glog-dir: not a git repository: %s\n' "$_gd_repo" >&2
        return 1
    }

    if [ -n "$_gd_branch" ]; then
        _gd_ref=$_gd_branch
    else
        _gd_ref=
        for _gd_try in origin/main origin/master main master; do
            if git -C "$_gd_root" rev-parse --verify --quiet "$_gd_try" >/dev/null 2>&1; then
                _gd_ref=$_gd_try
                break
            fi
        done
        if [ -z "$_gd_ref" ]; then
            printf 'glog-dir: could not find a main/master branch in %s\n' "$_gd_root" >&2
            return 1
        fi
    fi

    # A stale local clone would otherwise report an out-of-date "latest".
    case "$_gd_ref" in
        */*)
            if [ "$_gd_fetch" -eq 1 ]; then
                _gd_remote=${_gd_ref%%/*}
                git -C "$_gd_root" fetch --quiet "$_gd_remote" \
                    "${_gd_ref#*/}" 2>/dev/null ||
                    printf 'glog-dir: fetch failed, showing cached %s\n' "$_gd_ref" >&2
            fi ;;
    esac

    # A bound is a commit if it has no spaces and the repo can resolve it;
    # anything else is treated as a date.
    _gd_lo_commit= _gd_hi_commit=
    for _gd_side in lo hi; do
        eval "_gd_raw=\$_gd_${_gd_side}_raw"
        [ -z "$_gd_raw" ] && continue
        case "$_gd_raw" in
            *\ *) _gd_is_rev=0 ;;
            *) if git -C "$_gd_root" rev-parse --verify --quiet "${_gd_raw}^{commit}" >/dev/null 2>&1
               then _gd_is_rev=1; else _gd_is_rev=0; fi ;;
        esac

        if [ "$_gd_is_rev" -eq 1 ]; then
            if ! git -C "$_gd_root" merge-base --is-ancestor "$_gd_raw" "$_gd_ref" 2>/dev/null; then
                printf 'glog-dir: warning: %s is not on %s\n' "$_gd_raw" "$_gd_ref" >&2
            fi
            eval "_gd_${_gd_side}_commit=\$_gd_raw"
        else
            _gd_norm=$(_glog_dir_norm_date "$_gd_raw")
            _glog_dir_check_date "$_gd_root" "$_gd_raw" "$_gd_norm" || return 2
            eval "_gd_${_gd_side}=\$_gd_norm"
        fi
    done

    # Commit bounds become a real revision range; date bounds stay as flags.
    _gd_range=$_gd_ref
    if [ -n "$_gd_hi_commit" ]; then
        if [ "$_gd_hi_incl" -eq 1 ]; then
            _gd_range=$_gd_hi_commit
        else
            _gd_range=$_gd_hi_commit^
        fi
    fi
    if [ -n "$_gd_lo_commit" ]; then
        _gd_start=$_gd_lo_commit
        # Inclusive lower bound needs the parent; a root commit has none.
        if [ "$_gd_lo_incl" -eq 1 ] &&
           git -C "$_gd_root" rev-parse --verify --quiet "${_gd_lo_commit}^" >/dev/null 2>&1; then
            _gd_start=$_gd_lo_commit^
        fi
        _gd_range="${_gd_start}..${_gd_range}"
    fi

    # Absolutize so the pathspec means what the user sees, since git -C makes
    # the repo root the cwd and would otherwise reinterpret relative paths.
    # Try the caller's cwd first, then the -C/GLOG_DIR_REPO directory, which
    # matters when that directory is a subdirectory of the repo root.
    _gd_target=$_gd_path
    for _gd_base in . "$_gd_repo"; do
        [ -e "$_gd_base/$_gd_path" ] || continue
        _gd_abs=$(cd "$(dirname -- "$_gd_base/$_gd_path")" && pwd)/$(basename -- "$_gd_path")
        case "$_gd_abs" in
            "$_gd_root"/*|"$_gd_root") _gd_target=$_gd_abs; break ;;
        esac
    done

    _gd_names=
    [ "$_gd_files" -eq 1 ] && _gd_names=--name-only

    _gd_out=$(git -C "$_gd_root" log "$_gd_range" \
        --max-count="$_gd_count" \
        --date=short \
        ${_gd_names:+"$_gd_names"} \
        ${_gd_lo:+--since="$_gd_lo"} \
        ${_gd_hi:+--until="$_gd_hi"} \
        --color=always \
        --pretty=format:'%C(auto)%h%Creset %C(dim)%ad%Creset %C(bold blue)%an%Creset %s' \
        "$@" \
        -- "$_gd_target") || return $?

    if [ -n "$_gd_out" ]; then
        printf '%s\n' "$_gd_out"
        return 0
    fi

    # Distinguish "nothing in this time window" from "that path isn't tracked".
    if git -C "$_gd_root" log "$_gd_ref" --max-count=1 --format=%h \
           -- "$_gd_target" 2>/dev/null | grep -q .; then
        printf 'glog-dir: no commits touching %s on %s in that range\n' \
            "$_gd_path" "$_gd_ref" >&2
    else
        printf 'glog-dir: no commits touching %s on %s (is it tracked? repo root is %s)\n' \
            "$_gd_path" "$_gd_ref" "$_gd_root" >&2
    fi
    return 1
}

# Convenience aliases.
alias gld='glog-dir'
alias gldf='glog-dir --files'
