# ~~~~~~~~~~~~~~~~~~ Aliases[Config]~~~~~~~~~~~~~~~~~~~
# ${EDITOR:-code} so these still work on a machine without VS Code installed.
alias z,='${EDITOR:-code} $ZSH_CONFIG/home/.zshrc'
alias v,='${EDITOR:-code} $ZSH_CONFIG/home/.vimrc'
alias a,='${EDITOR:-code} $ZSH_HOME/aliases.zsh'
alias f,='${EDITOR:-code} $ZSH_HOME/functions.zsh'
alias l,='${EDITOR:-code} $ZSH_HOME/local.zsh'
alias zc='cd $ZSH_CONFIG'

# ~~~~~~~~~~~~~~~~~~ Aliases[Misc]~~~~~~~~~~~~~~~~~~~
alias cpwd='pwd | pbcopy' # copy current working directory to clipboard
alias cpl='fc -ln -1 | pbcopy' # copy last command to clipboard
alias cpo='eval "$(fc -ln -1)" | pbcopy' # copy last output to clipboard

alias src='exec zsh' # reload zsh configuration
alias o='open -a' # open with default application
alias cls='clear' # clear terminal
alias pb='pbcopy' # copy to clipboard
alias pbp='pbpaste' # paste from clipboard
alias mkdir='mkdir -p' # create parent directories as needed

alias swbg='\
    osascript -e \
    "tell application \"System Events\" to tell appearance \
    preferences to set dark mode to not dark mode" \
' # Toggle system dark/light mode

# alias _ssh='ssh' # Save original ssh command before overriding defaults
# alias ssh='ssh -o "StrictHostKeyChecking no"'

# ~~~~~~~~~~~~~~~~~~ Aliases[Locations]~~~~~~~~~~~~~~~~~~~
alias hh='cd "$(git rev-parse --show-toplevel)"'
alias hhh='cd $HOME'

alias ..='cd ..' # go up one directory
alias ...='cd ../..' # go up two directories
alias ....='cd ../../..' # go up three directories
alias .....='cd ../../..' # go up 4 directories

alias data='cd ~/Data'
alias docs='cd ~/Documents'
alias down='cd ~/Downloads'
alias desk='cd ~/Desktop'
alias apps='cd /Applications'

export REPOS=~/Repos
export KBD=$REPOS/kbd

alias repos='cd $REPOS'
alias kbd='cd $KBD'
alias cokbd='code $KBD'

# ~~~~~~~~~~~~~~~~~~ Aliases[ls/Eza]~~~~~~~~~~~~~~~~~~~
alias _ls='ls' # Save original ls/eza commands before overriding defaults
alias _eza='\
    eza --all --group-directories-first --no-user --no-permissions \
    --classify --dereference --smart-group --time-style=+"%D - %I:%M%p" \
    --icons=always --color=always --color-scale=age --color-scale-mode=fixed \
' # Base eza command with preferred options

alias ls='_eza --grid' # Default ls uses grid
alias la='ls -1Alh --extended --bytes' # Long listing with header and total size

alias ll='la --total-size --sort=size' # Long listing sorted by size (warning SLOW)
alias lr='la --recurse --tree' # Long listing with tree view (warning SLOW)
alias llr='ll --recurse --tree --sort=size' # Long listing sorted by size with tree view (warning VERY SLOW)

alias lt='la --modified --created --accessed'  # la with all time columns
alias lta='lt --sort=accessed' # la sorted by accessed
alias ltc='lt  --sort=created' # la sorted by created
alias ltm='lt  --sort=modified' # la sorted by modified

# ~~~~~~~~~~~~~~~~~~ Aliases[Git]~~~~~~~~~~~~~~~~~~~
alias gc='git checkout'
alias gbr='git branch --no-ignore-case'

alias gs='git status --untracked-files -M --show-stash'
alias gf='git fetch --prune'
# Fix "cannot lock ref" fetch errors: pack refs, delete any offending remote-tracking refs, re-fetch
alias gfrs='git pack-refs --all --prune; git fetch origin 2>&1 | grep -oE "refs/remotes/origin/[^'\'']+'\''" | tr -d "'\''" | while read r; do git update-ref -d "$r"; done; git fetch origin'

alias grev='git rev-parse HEAD | pbcopy' # Get short hash of current commit

alias ga='git add'
alias gaa='ga --all "$(git rev-parse --show-toplevel)"' # Add everything possible

alias grm='git restore --staged --worktree --no-overlay' # Remove staged/unstaged/untracked files (use with caution)
alias gcls='grm "$(git rev-parse --show-toplevel)"' # Remove EVERYTHING outputted by `git status` to get into a clean state

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Commit]~~~~~~~~~~~~~~~~~~~
alias gcM='git commit --no-verify'
alias gcm='gcM -m'  # Commit with message
alias gcam='gaa && gcM  -m' # Add everything and commit with message

alias gfq='gcM --amend --no-edit' # Fixup previous commit
alias gfaq='gaa && gfq'  # Fixup everything into previous commit

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Checkout]~~~~~~~~~~~~~~~~~~~
alias gcf='git checkout --no-overlay --force'
alias gcfme='gcf @{u} -- '

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Reset]~~~~~~~~~~~~~~~~~~~
alias grs='git reset --hard'
alias grsme='grs @{u}'

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Rebase]~~~~~~~~~~~~~~~~~~~
alias grb='git rebase --no-verify -i'
alias grba='git rebase --abort'
alias grbq='git rebase --quit'
alias grbs='git rebase  --skip'
alias grbc='git rebase  --continue'
alias grbC='git commit --amend --no-edit --no-verify && git rebase --continue'
alias grbme='git rebase -i --no-verify @{u}'

# ~~~~~~~~~~~~~~~~~~ Aliases[Git][Push]~~~~~~~~~~~~~~~~~~~
alias gpsh='git push --no-verify'
alias gfpsh='gpsh --force-with-lease'
alias gffpsh='gfpsh --force'

# ~~~~~~~~~~~~~~~~~~ Aliases[Python]~~~~~~~~~~~~~~~~~~~
alias ipy='ipython --quick --profile=custom'
