# ~~~~~~~~~~~~~~~~~~ Powerlevel10k instant prompt - KEEP AT TOP ~~~~~~~~~~~~~~~~~~~
# Must stay above anything that prints output or reads from stdin.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ~~~~~~~~~~~~~~~~~~ Locate this repo ~~~~~~~~~~~~~~~~~~~
# ~/.zshrc is a symlink into the zsh-config checkout; :A resolves it, so the
# repo can live anywhere without editing a single path below.
ZSH_CONFIG=${${(%):-%N}:A:h:h}
[[ -d $ZSH_CONFIG/zsh ]] || ZSH_CONFIG=$HOME/zsh-config
export ZSH_CONFIG
export ZSH_HOME=$ZSH_CONFIG/zsh
export ZSH_PLUGINS=$ZSH_CONFIG/plugins

# ~~~~~~~~~~~~~~~~~~ Homebrew ~~~~~~~~~~~~~~~~~~~
# Apple Silicon uses /opt/homebrew, Intel uses /usr/local. Do this early so
# everything below can rely on $HOMEBREW_PREFIX and on brew binaries in PATH.
if [[ -z $HOMEBREW_PREFIX ]]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $_brew ]] && eval "$($_brew shellenv)" && break
  done
  unset _brew
fi

# ~~~~~~~~~~~~~~~~~~ Powerlevel10k theme ~~~~~~~~~~~~~~~~~~~
if [[ -r $ZSH_PLUGINS/powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source $ZSH_PLUGINS/powerlevel10k/powerlevel10k.zsh-theme
elif [[ -r $HOME/powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source $HOME/powerlevel10k/powerlevel10k.zsh-theme
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ~~~~~~~~~~~~~~~~~~ Env vars ~~~~~~~~~~~~~~~~~~~
export CLICOLOR=1
export LS_COLORS='di=1:fi=96:*.m=31:*.py=32:*.txt=36:*.out=35'

export DISABLE_UPDATE_PROMPT=false
export ENABLE_CORRECTION=true
export HYPHEN_INSENSITIVE=true
export WORDCHARS=0
export HOMEBREW_NO_AUTO_UPDATE=1
export CASE_SENSITIVE=false

# ~~~~~~~~~~~~~~~~~~ Dotfiles ~~~~~~~~~~~~~~~~~~~
source $ZSH_HOME/aliases.zsh
source $ZSH_HOME/functions.zsh
source $ZSH_HOME/git-dirlog.sh

pyinit
fzfinit
setkeybindings

# ~~~~~~~~~~~~~~~~~~ History ~~~~~~~~~~~~~~~~~~~
setopt APPEND_HISTORY SHARE_HISTORY HIST_EXPIRE_DUPS_FIRST EXTENDED_HISTORY
HISTFILE=$HOME/.zhistory
SAVEHIST=10000
HISTSIZE=9999

# ~~~~~~~~~~~~~~~~~~ Z ~~~~~~~~~~~~~~~~~~~
[[ -r $ZSH_PLUGINS/zsh-z/zsh-z.plugin.zsh ]] && source $ZSH_PLUGINS/zsh-z/zsh-z.plugin.zsh
ZSHZ_CASE="smart"
ZSHZ_CD="cd"
ZSHZ_COMPLETION="legacy"

# ~~~~~~~~~~~~~~~~~~ Autosuggest/Completion ~~~~~~~~~~~~~~~~~~~
[[ -r $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history match_prev_cmd)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=131,standout"

# ~~~~~~~~~~~~~~~~~~ Syntax Highlighting ~~~~~~~~~~~~~~~~~~~
[[ -r $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=011"
ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=126,underline"
ZSH_HIGHLIGHT_STYLES[alias]="fg=37"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=81,bold"
ZSH_HIGHLIGHT_STYLES[function]="fg=79,bold"
ZSH_HIGHLIGHT_STYLES[command]="fg=80"
ZSH_HIGHLIGHT_STYLES[path]="fg=177,underline"
ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=cyan,standout"
ZSH_HIGHLIGHT_STYLES[arg0]="fg=67,bold"
ZSH_HIGHLIGHT_STYLES[default]="fg=005"
ZSH_HIGHLIGHT_HIGHLIGHTERS+=(brackets pattern cursor)

# ~~~~~~~~~~~~~~~~~~ PATH ~~~~~~~~~~~~~~~~~~~
# Only prepend entries that actually exist, so a fresh Mac missing one of these
# doesn't end up with a PATH full of dead directories.
path_prepend() { [[ -d $1 ]] && path=("$1" $path) }
path_append()  { [[ -d $1 ]] && path+=("$1") }

path_prepend "$HOMEBREW_PREFIX/opt/node@22/bin"
path_prepend "$HOMEBREW_PREFIX/opt/openjdk/bin"
path_prepend "$HOMEBREW_PREFIX/opt/mosquitto/sbin"
path_append  "/Applications/Sublime Merge.app/Contents/SharedSupport/bin"

# ~~~~~~~~~~~~~~~~~~ Java / Android ~~~~~~~~~~~~~~~~~~~
[[ -d $HOMEBREW_PREFIX/opt/openjdk@21 ]] &&
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
[[ -d $HOMEBREW_PREFIX/share/android-commandlinetools ]] &&
  export ANDROID_HOME="$HOMEBREW_PREFIX/share/android-commandlinetools"
path_prepend "$JAVA_HOME/bin"
path_prepend "$ANDROID_HOME/platform-tools"

typeset -U path PATH   # de-duplicate PATH, keeping first occurrence
unset -f path_prepend path_append

# ~~~~~~~~~~~~~~~~~~ Rust ~~~~~~~~~~~~~~~~~~~
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# ~~~~~~~~~~~~~~~~~~ Machine-local overrides ~~~~~~~~~~~~~~~~~~~
# Not tracked in git: work paths, proxies, secrets, per-machine SDKs.
[[ -r $ZSH_HOME/local.zsh ]] && source $ZSH_HOME/local.zsh
