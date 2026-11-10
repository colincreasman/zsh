# Linux entry point. The aliases, widgets and prompt remain shared with macOS.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export ZSH_CONFIG=${${(%):-%N}:A:h:h}
export ZSH_HOME=$ZSH_CONFIG/zsh
export ZSH_PLUGINS=${XDG_DATA_HOME:-$HOME/.local/share}/zsh-config/plugins
typeset -U path PATH
path=("$HOME/.local/bin" $path)
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
export CLICOLOR=1
export LS_COLORS='di=1:fi=96:*.m=31:*.py=32:*.txt=36:*.out=35'
export EDITOR='code --wait'
export COPILOT_EDITOR='code --wait'

source "$ZSH_PLUGINS/powerlevel10k/powerlevel10k.zsh-theme"
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
source "$ZSH_HOME/aliases.zsh"
source "$ZSH_HOME/functions.zsh"
source "$ZSH_HOME/git-dirlog.sh"

# Use Windows' clipboard and default application, not the macOS integrations.
function pbcopy() {
  pwsh.exe -NoLogo -NoProfile -NonInteractive -Command \
    '[Console]::InputEncoding = [Text.UTF8Encoding]::new(); Set-Clipboard -Value ([Console]::In.ReadToEnd())'
}
function pbpaste() {
  pwsh.exe -NoLogo -NoProfile -NonInteractive -Command \
    '[Console]::OutputEncoding = [Text.UTF8Encoding]::new(); [Console]::Write((Get-Clipboard -Raw))'
}
unalias o swbg
function o() {
  if (( $# != 1 )); then print -u2 'usage: o <path|url>'; return 1; fi
  local target=$1
  [[ $target == *://* ]] || target=$(wslpath -w -- "$target") || return
  ZSH_OPEN_TARGET=$target WSLENV="${WSLENV:+$WSLENV:}ZSH_OPEN_TARGET" \
    pwsh.exe -NoLogo -NoProfile -NonInteractive -Command 'Start-Process -FilePath $env:ZSH_OPEN_TARGET'
}
function swbg() { print -u2 'swbg is not supported in WSL; select a Windows Terminal color scheme instead.'; return 1; }
function airdrop() { print -u2 'AirDrop is macOS-only.'; return 1; }
export REPOS=$HOME/Repos
export KBD=$REPOS/kbd
alias 'z,=${EDITOR:-code} $ZSH_CONFIG/wsl/.zshrc'
alias 'l,=${EDITOR:-code} $ZSH_CONFIG/wsl/local.zsh'
alias 'f,=${EDITOR:-code} $ZSH_HOME/functions.zsh'
unalias docs down desk data
function _wsl_cd_windows() {
  local destination
  destination=$(ZSH_WINDOWS_FOLDER=$1 WSLENV="${WSLENV:+$WSLENV:}ZSH_WINDOWS_FOLDER" \
    pwsh.exe -NoLogo -NoProfile -NonInteractive -Command \
      'switch ($env:ZSH_WINDOWS_FOLDER) { "Downloads" { Join-Path $env:USERPROFILE "Downloads" }; "Data" { Join-Path $env:USERPROFILE "Data" }; default { [Environment]::GetFolderPath($env:ZSH_WINDOWS_FOLDER) } }') || return
  cd "$(wslpath "${destination//$'\r'/}")"
}
function docs() { _wsl_cd_windows MyDocuments }
function down() { _wsl_cd_windows Downloads }
function desk() { _wsl_cd_windows Desktop }
function data() { _wsl_cd_windows Data }
alias apps='cd /mnt/c/Program\ Files'

pyinit
fzfinit
# zsh-z candidates are not tagged as files, so fzf-tab only supplies $word.
for _z_command in z zshz; do
  zstyle ":fzf-tab:complete:$_z_command:*" fzf-preview \
    'eza -1a --group-directories-first --classify --sort=name --color=always -- "${realpath:-$word}"'
done
unset _z_command
setkeybindings
bindkey '^Z' undo
bindkey '^Y' redo
bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word

setopt APPEND_HISTORY SHARE_HISTORY HIST_EXPIRE_DUPS_FIRST EXTENDED_HISTORY
HISTFILE=$HOME/.zhistory
SAVEHIST=10000
HISTSIZE=9999
ZSHZ_CASE=smart
ZSHZ_CD=cd
ZSHZ_COMPLETION=legacy
source "$ZSH_PLUGINS/zsh-z/zsh-z.plugin.zsh"
# compinit ran before zsh-z added its fpath; register both the alias and its
# expansion explicitly instead of falling back to ordinary file completion.
autoload -Uz _zshz
compdef _zshz z zshz
source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
ZSH_AUTOSUGGEST_STRATEGY=(history match_prev_cmd)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=131,standout'
source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=011'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=126,underline'
ZSH_HIGHLIGHT_STYLES[alias]='fg=37'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=81,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=79,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=80'
ZSH_HIGHLIGHT_STYLES[path]='fg=177,underline'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=cyan,standout'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=67,bold'
ZSH_HIGHLIGHT_STYLES[default]='fg=005'
ZSH_HIGHLIGHT_HIGHLIGHTERS+=(brackets pattern cursor)
[[ -r "$ZSH_CONFIG/wsl/local.zsh" ]] && source "$ZSH_CONFIG/wsl/local.zsh"
