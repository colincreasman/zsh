#!/usr/bin/env bash
# Install the shared zsh setup in Ubuntu/Debian WSL. Run as your Linux user.
# Usage: bash wsl/install.sh [--no-packages] [--default-shell]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS="${XDG_DATA_HOME:-$HOME/.local/share}/zsh-config/plugins"
STAMP="$(date +%Y%m%d%H%M%S%N)"
PACKAGES=1
DEFAULT_SHELL=0
for arg in "$@"; do
  case "$arg" in
    --no-packages) PACKAGES=0 ;;
    --default-shell) DEFAULT_SHELL=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
[[ "$(uname)" == Linux ]] || { echo 'Linux only.' >&2; exit 1; }
[[ $EUID != 0 ]] || { echo 'Run as your Linux user, not root.' >&2; exit 1; }

if [[ $PACKAGES == 1 ]]; then
  sudo apt-get update
  sudo apt-get install -y zsh git curl ca-certificates unzip bat
fi
for tool in zsh git curl tar; do
  command -v "$tool" >/dev/null || { echo "Missing dependency: $tool" >&2; exit 1; }
done

mkdir -p "$PLUGINS" "$HOME/.local/bin" "$HOME/Repos"
clone() {
  if [[ ! -d "$PLUGINS/$2/.git" ]]; then
    git clone --depth=1 "https://github.com/$1.git" "$PLUGINS/$2"
  else
    echo "Already installed: $2"
  fi
}
clone romkatv/powerlevel10k powerlevel10k
clone agkozak/zsh-z zsh-z
clone Aloxaf/fzf-tab fzf-tab
clone zsh-users/zsh-autosuggestions zsh-autosuggestions
clone zsh-users/zsh-syntax-highlighting zsh-syntax-highlighting

# Jammy's fzf predates --zsh; keep a recent upstream binary in the Linux home.
if ! "$HOME/.local/bin/fzf" --zsh >/dev/null 2>&1; then
  clone junegunn/fzf fzf
  "$PLUGINS/fzf/install" --bin
  ln -sfn "$PLUGINS/fzf/bin/fzf" "$HOME/.local/bin/fzf"
fi
if ! command -v eza >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/eza" ]]; then
  case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64) arch=aarch64 ;;
    *) echo 'Unsupported eza CPU architecture.' >&2; exit 1 ;;
  esac
  tmp="$(mktemp -d)"
  trap 'rm -f "$tmp/eza.tar.gz" "$tmp/eza"; rmdir "$tmp"' EXIT
  curl -fL --retry 3 "https://github.com/eza-community/eza/releases/latest/download/eza_${arch}-unknown-linux-gnu.tar.gz" -o "$tmp/eza.tar.gz"
  tar -xzf "$tmp/eza.tar.gz" -C "$tmp" ./eza
  install -m 755 "$tmp/eza" "$HOME/.local/bin/eza"
  rm "$tmp/eza.tar.gz" "$tmp/eza"
  rmdir "$tmp"
  trap - EXIT
fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

"$PLUGINS/powerlevel10k/gitstatus/install" -f
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then return; fi
  if [[ -e "$dest" || -L "$dest" ]]; then mv "$dest" "$dest.bak-$STAMP"; fi
  ln -s "$src" "$dest"
}
link "$REPO/wsl/.zshrc" "$HOME/.zshrc"
link "$REPO/home/.p10k.zsh" "$HOME/.p10k.zsh"
if [[ ! -f "$REPO/wsl/local.zsh" ]]; then
  cp "$REPO/wsl/local.zsh.example" "$REPO/wsl/local.zsh"
fi
if [[ $DEFAULT_SHELL == 1 && "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  chsh -s "$(command -v zsh)"
fi
export PATH="$HOME/.local/bin:$PATH"
zsh -n "$REPO/wsl/.zshrc"
for tool in zsh fzf eza bat; do command -v "$tool"; done
echo 'Ready. Open the chaf-dynamic WSL Terminal profile (or run exec zsh -l).'
