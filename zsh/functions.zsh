# ~~~~~~~~~~~~~~~~~~ Functions[Output Capture] ~~~~~~~~~~~~~~~~~~~
# Capture last command output without re-running
# Usage: run a command normally, then call `cpout` to copy its output
# function cpout() {
#     # Use fc to get last command and execute it with tee to capture output
#     # This does require running it, but only once when explicitly called
#     local cmd=$(fc -ln -1)
#     eval "$cmd" 2>&1 | tee >(pbcopy)
# }

# ~~~~~~~~~~~~~~~~~~ Functions[Git ] ~~~~~~~~~~~~~~~~~~~
function grbours() {
    [ $# -gt 0 ] && _PATH_=$1
    git checkout --ours -- $_PATH_ && git add $_PATH_
}
function grbtheirs() {
    [ $# -gt 0 ] && _PATH_=$1
    git checkout --theirs -- $_PATH_ && git add $_PATH_
}
function grbog() {
    [[ -z $MAIN ]] && export MAIN="$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')"
    git rebase --no-verify -i -- origin/$MAIN
}
function gcfog() {
    [ $# -gt 0 ] && _PATH_=$1
    [[ -z $MAIN ]] && export MAIN="$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')"
    git checkout --no-overlay --force origin/$MAIN -- $_PATH_
}
function grsog() {
    [[ -z $MAIN ]] && export MAIN="$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')"
    git reset --hard origin/$MAIN
}
# ~~~~~~~~~~~~~~~~~~ Functions[PS] ~~~~~~~~~~~~~~~~~~~
function psls() {
    ps aux | grep -i $1 | grep -v grep
}

function pskill() {
    cnt=$( psls $1 | wc -l)  # total count of processes found
    echo -e "\nSearching for '$1' -- Found" $cnt "Running Processes .. "
    psls $1
    echo -e '\nTerminating' $cnt 'processes .. '
    ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}' | xargs kill -9
    echo -e "Done!\n"
    echo "Running search again:"
    psls "$1"
    echo -e "\n"
}

function unsetproxies() {
    unset http_proxy
    unset https_proxy
    unset no_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset NO_PROXY
}
# ~~~~~~~~~~~~~~~~~~ History browsing as ghost text ~~~~~~~~~~~~~~~~~~~
# Up/Down browse history without ever touching the real buffer: the candidate
# is shown as dim POSTDISPLAY text (identical to zsh-autosuggestions) and is
# only committed with ^Space (whole) / opt+Space (one word).
# Whatever is already typed acts as the filter, so `git config` + Up only
# offers entries starting with `git config`.
#
# NOTE: every widget below is named with a leading underscore on purpose --
# zsh-autosuggestions skips `_*` widgets when it wraps ZLE, so it will not
# clobber the POSTDISPLAY we set. We drive its highlighter ourselves.

typeset -g _HS_PREFIX=''
typeset -ga _HS_MATCHES=()
typeset -gi _HS_IDX=0

function _hs_highlight_reset() {
    if (( ${+functions[_zsh_autosuggest_highlight_reset]} )); then
        _zsh_autosuggest_highlight_reset
    fi
}

function _hs_highlight_apply() {
    if (( ${+functions[_zsh_autosuggest_highlight_apply]} )); then
        _zsh_autosuggest_highlight_apply
    elif (( $#POSTDISPLAY )); then
        region_highlight+=("$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) ${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE:-fg=8}")
    fi
}

# Newest-first, de-duplicated history entries starting with $1 (case-insensitive)
function _hs_matches() {
    emulate -L zsh
    setopt localoptions extendedglob
    local prefix=$1
    local -a all
    all=( ${(Oa)${(f)"$(fc -ln 1)"}} )      # oldest->newest, reversed
    all=( ${all##[[:space:]]##} )           # fc indents its output
    all=( ${(u)all:#} )                     # de-dupe (keeps newest), drop blanks
    if [[ -n $prefix ]]; then
        all=( ${(M)all:#(#i)${(b)prefix}*} )
        all=( ${all:#(#i)${(b)prefix}} )    # an exact echo of the input is not a suggestion
    fi
    print -rl -- $all
}

function _hs_show() {
    BUFFER=$_HS_PREFIX
    CURSOR=$#BUFFER
    if (( _HS_IDX > 0 )); then
        local cand=${_HS_MATCHES[$_HS_IDX]}
        POSTDISPLAY=${cand:$#_HS_PREFIX}
    else
        POSTDISPLAY=''
    fi
    _hs_highlight_apply
    zle -R
}

function _hs_hist_browse() {
    emulate -L zsh
    local dir=$1

    # Multi-line buffers: arrows keep moving between lines
    if [[ $BUFFER == *$'\n'* ]]; then
        _hs_highlight_reset
        POSTDISPLAY=''
        zle .${dir}-line
        return
    fi

    _hs_highlight_reset

    # Start a new browse session unless we are continuing one
    if [[ $LASTWIDGET != _hs-hist-(up|down) ]] || [[ $BUFFER != $_HS_PREFIX ]]; then
        _HS_PREFIX=$BUFFER
        _HS_MATCHES=( ${(f)"$(_hs_matches "$_HS_PREFIX")"} )
        _HS_IDX=0
    fi

    if (( $#_HS_MATCHES == 0 )); then
        POSTDISPLAY=''
        zle -R
        return 1
    fi

    if [[ $dir == up ]]; then
        (( _HS_IDX < $#_HS_MATCHES )) && (( _HS_IDX++ ))
    else
        (( _HS_IDX > 0 )) && (( _HS_IDX-- ))
    fi

    _hs_show
}

function _hs_hist_up()   { _hs_hist_browse up }
function _hs_hist_down() { _hs_hist_browse down }

# ^R: fzf over history, but the pick comes back as a ghost suggestion instead
# of being inserted -- commit it with ^Space / opt+Space, or edit around it.
function _hs_fzf_history() {
    emulate -L zsh
    setopt localoptions extendedglob pipefail no_aliases 2>/dev/null

    local query=$BUFFER selected cmd
    selected=$(
        fc -rl 1 |
            awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
            FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-60%} --layout=reverse --nth=2.. --tiebreak=index ${FZF_DEFAULT_OPTS} ${FZF_CTRL_R_OPTS} --query=${(qqq)query} +m" \
                fzf
    )

    if [[ -n $selected ]]; then
        cmd=${${selected##[[:space:]]#}##[0-9]##[*]#[[:space:]]#}
        _hs_highlight_reset
        if [[ -n $query && ${(L)cmd} == ${(L)query}* ]]; then
            BUFFER=$query
            POSTDISPLAY=${cmd:$#query}
        else
            BUFFER=''
            POSTDISPLAY=$cmd
        fi
        CURSOR=$#BUFFER
        _hs_highlight_apply
    fi

    zle reset-prompt
}

function setkeybindings() {
    bindkey -r "^X" && bindkey "^X" _expand_alias
    bindkey -r "^[-" && bindkey "^[-" redo # opt+_ for undo

    # `setkeybindings classic` restores the pre-ghost-history bindings live,
    # no reload required. `setkeybindings` (or `setkeybindings ghost`) = new behavior.
    if [[ ${1:-ghost} == classic ]]; then
        bindkey '^[[A' fzf-history-widget
        bindkey '^[[B' fzf-history-widget
        bindkey '^[OA' up-line-or-history      # zsh emacs-keymap defaults
        bindkey '^[OB' down-line-or-history
        bindkey '^R' fzf-history-widget
        bindkey "^ " autosuggest-accept
        bindkey "^[ " forward-word
        return
    fi

    zle -N _hs-hist-up _hs_hist_up
    zle -N _hs-hist-down _hs_hist_down
    zle -N _hs-fzf-history _hs_fzf_history

    bindkey '^[[A' _hs-hist-up      # up
    bindkey '^[[B' _hs-hist-down    # down
    bindkey '^[OA' _hs-hist-up      # up   (application cursor mode)
    bindkey '^[OB' _hs-hist-down    # down (application cursor mode)
    bindkey '^R' _hs-fzf-history
    bindkey "^ " autosuggest-accept          # ctrl+space  -> accept whole ghost
    bindkey "^[ " forward-word               # opt+space   -> accept one word
                                             # (zsh-autosuggestions treats forward-word
                                             #  as a partial-accept widget)
}

# ~~~~~~~~~~~~~~~~~~ Python ~~~~~~~~~~~~~~~~~~~
function pyinit() {
    export PATH=$HOME/.local/bin:$PATH
    export PYENV_ROOT=$HOME/.pyenv
    [[ -d $PYENV_ROOT/bin ]] && export PATH=$PYENV_ROOT/bin:$PATH
    (( $+commands[pyenv] )) || return 0
    eval "$(pyenv init -)"
    export PYENV_HOME=$PYENV_ROOT/versions/$(pyenv version-name --local)
}

# ~~~~~~~~~~~~~~~~~~ fzf ~~~~~~~~~~~~~~~~~~~
function lscolors() {
  for i in {0..255}; do
    print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'};
  done
}

function fzfinit() {
    fpath+=~/.zfunc
    (( $+commands[fzf] )) && eval "$(fzf --zsh)"

    # -i ignores "insecure directories" instead of blocking the first shell on a
    # fresh Mac with an interactive [y/n/a] prompt (group-writable brew dirs).
    autoload -Uz compinit && compinit -i

    [[ -r $ZSH_PLUGINS/fzf-tab/fzf-tab.zsh ]] && source $ZSH_PLUGINS/fzf-tab/fzf-tab.zsh
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

    zstyle ':fzf-tab:*' switch-group 'left' 'right'

    # eza contents preview for commands expecting path arg
    zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:_eza:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:find:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:tail:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:rm:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:mkdir:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:cat:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:mv:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:cp:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:chmod:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:sh:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'
    zstyle ':fzf-tab:complete:exec:*' fzf-preview 'eza -1a --group-directories-first --classify --sort=name --color=always $realpath'

    # Preview the value of an environment variable when tabbing into it
    zstyle ':fzf-tab:complete:(-command-|-parameter-|-export-):*' fzf-preview 'echo ${(P)word}'

    zstyle ':completion:*' completer _expand_alias _complete _ignored
    zstyle ':completion:*' regular true


}
