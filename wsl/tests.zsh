# Run after installing: zsh -lic 'source /path/to/repo/wsl/tests.zsh'
function _shell_parity_test() {
  emulate -L zsh
  local expected=${1:-$ZSH_CONFIG}
  [[ $ZSH_CONFIG == $expected ]] || { print -u2 'Wrong configuration path'; return 1; }
  [[ ${widgets[_hs-hist-up]} == user:* ]] || return 1
  [[ ${widgets[_hs-fzf-history]} == user:* ]] || return 1
  [[ ${widgets[_copy-selection]} == user:* ]] || return 1
  [[ $(bindkey '^R') == *'_hs-fzf-history' ]] || return 1
  [[ $(bindkey '^ ') == *'autosuggest-accept' ]] || return 1
  [[ $(bindkey '^[ ') == *'forward-word' ]] || return 1
  [[ ${ZSHZ[TAB_BINDING]} == *fzf-tab* ]] || return 1
  [[ ${_comps[z]} == _zshz && ${_comps[zshz]} == _zshz ]] || return 1
  local preview
  zstyle -s ':fzf-tab:complete:z:*' fzf-preview preview || return 1
  [[ $preview == *eza* && $preview == *'${realpath:-$word}'* ]] || return 1
  local tool
  for tool in zsh fzf eza bat pwsh.exe; do
    (( $+commands[$tool] )) || { print -u2 "Missing $tool"; return 1; }
  done
  fzf --zsh >/dev/null || return 1
  eza --all --group-directories-first --no-user --no-permissions \
    --classify --dereference --smart-group '--time-style=+%D - %I:%M%p' \
    --icons=always --color=always --color-scale=age --color-scale-mode=fixed \
    "$ZSH_CONFIG/wsl" >/dev/null || return 1
  local result
  result=$(function pbcopy() { cat >/dev/null }; ghash ABCDEF1234567890) || return 1
  [[ $result == abcdef12 ]] || return 1
  print 'PASS: shared ghost-history widgets, accept keys, fzf-tab/zsh-z bridge, eza preview styles and ghash.'
}
_shell_parity_test "$@" || { print -u2 'FAIL: WSL shell parity'; return 1; }
unfunction _shell_parity_test
