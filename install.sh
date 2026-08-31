#!/usr/bin/env bash
# install.sh - reproduce this zsh + Powerlevel10k + Terminal.app setup on a Mac.
#
# Usage:
#   ./install.sh              # everything (safe to re-run)
#   ./install.sh --no-brew    # skip Homebrew/package installation
#   ./install.sh --no-terminal# skip the Terminal.app profile import
#   ./install.sh --no-extras  # skip optional pyenv/rustup/ipython setup
#
# Every step is idempotent. Existing real dotfiles are never deleted -- they are
# moved to <file>.bak-<timestamp> before being replaced with a symlink.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"
DO_BREW=1
DO_TERMINAL=1
DO_EXTRAS=1

for arg in "$@"; do
  case "$arg" in
    --no-brew)     DO_BREW=0 ;;
    --no-terminal) DO_TERMINAL=0 ;;
    --no-extras)   DO_EXTRAS=0 ;;
    -h|--help)     sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }

[[ "$(uname)" == "Darwin" ]] || { warn "macOS only."; exit 1; }

# ------------------------------------------------------------------
# 1. Homebrew + packages
# ------------------------------------------------------------------
if [[ $DO_BREW == 1 ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # Works on both Apple Silicon (/opt/homebrew) and Intel (/usr/local).
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $b ]] && eval "$("$b" shellenv)" && break
  done
  info "Installing packages from Brewfile (this takes a while)..."
  brew bundle --file "$REPO/Brewfile" || warn "brew bundle had failures; continuing."
  ok "Homebrew packages done."
else
  warn "Skipping Homebrew step (--no-brew)."
fi

# ------------------------------------------------------------------
# 2. zsh plugins (git clones into ./plugins, which is gitignored)
# ------------------------------------------------------------------
clone_or_update() {
  local url="$1" dir="$2"
  if [[ -d "$dir/.git" ]]; then
    info "Updating $(basename "$dir")..."
    git -C "$dir" pull --ff-only --quiet || warn "could not update $dir"
  else
    info "Cloning $url"
    git clone --depth=1 "$url" "$dir"
  fi
  ok "$dir"
}

mkdir -p "$REPO/plugins"
clone_or_update https://github.com/romkatv/powerlevel10k.git "$REPO/plugins/powerlevel10k"
clone_or_update https://github.com/agkozak/zsh-z.git         "$REPO/plugins/zsh-z"
clone_or_update https://github.com/Aloxaf/fzf-tab            "$REPO/plugins/fzf-tab"

# Powerlevel10k's `vcs` segment is driven by gitstatusd, a binary that is NOT
# bundled with the repo -- it is fetched into ~/.cache/gitstatus on first use.
# Pre-fetch it here so the very first prompt is fast and never shows
# "gitstatus failed to initialize".
GITSTATUS_INSTALL="$REPO/plugins/powerlevel10k/gitstatus/install"
if [[ -x "$GITSTATUS_INSTALL" ]]; then
  info "Pre-fetching gitstatusd (powers the p10k git prompt)..."
  if "$GITSTATUS_INSTALL" -f >/dev/null 2>&1; then
    ok "gitstatusd ready: $(ls "$HOME"/.cache/gitstatus/gitstatusd-* 2>/dev/null | head -1)"
  else
    warn "gitstatusd pre-fetch failed; p10k will retry on first prompt."
  fi
fi

# ------------------------------------------------------------------
# 3. Symlink dotfiles into $HOME (backing up anything already there)
# ------------------------------------------------------------------
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    ln -sfn "$src" "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.bak-$TS"
    warn "backed up $dest -> $(basename "$dest").bak-$TS"
    ln -sfn "$src" "$dest"
  else
    ln -sfn "$src" "$dest"
  fi
  ok "linked $dest"
}

info "Linking dotfiles..."
for f in "$REPO"/home/.*; do
  [[ -f "$f" ]] || continue
  link "$f" "$HOME/$(basename "$f")"
done

# Machine-local overrides: seed from the example, never overwrite.
if [[ ! -f "$REPO/zsh/local.zsh" ]]; then
  cp "$REPO/zsh/local.zsh.example" "$REPO/zsh/local.zsh"
  ok "created zsh/local.zsh (edit it for machine-specific config)"
fi

# ------------------------------------------------------------------
# 4. Terminal.app profile
# ------------------------------------------------------------------
if [[ $DO_TERMINAL == 1 ]]; then
  PROFILE_NAME="chaf-dynamic"
  PROFILE_FILE="$REPO/terminal/$PROFILE_NAME.terminal"
  if [[ -f "$PROFILE_FILE" ]]; then
    if defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q "\"$PROFILE_NAME\""; then
      ok "Terminal profile '$PROFILE_NAME' already imported."
    else
      info "Importing Terminal profile '$PROFILE_NAME'..."
      open "$PROFILE_FILE"
      sleep 2
    fi
    defaults write com.apple.Terminal "Default Window Settings" -string "$PROFILE_NAME" || true
    defaults write com.apple.Terminal "Startup Window Settings" -string "$PROFILE_NAME" || true
    ok "Set '$PROFILE_NAME' as the default Terminal profile."

    # An already-imported profile keeps whatever keyMapBoundKeys it was imported
    # with, so re-sync them from the repo profile. Terminal.app rewrites its
    # Window Settings on quit, so run this with Terminal closed (or re-run it)
    # if the bindings ever revert.
    info "Syncing scroll key bindings into the live '$PROFILE_NAME' profile..."
    if PROFILE_FILE="$PROFILE_FILE" PROFILE_NAME="$PROFILE_NAME" python3 - <<'PY'
import os, plistlib, subprocess, sys, tempfile

name = os.environ["PROFILE_NAME"]
repo_profile = plistlib.load(open(os.environ["PROFILE_FILE"], "rb"))
wanted = repo_profile.get("keyMapBoundKeys", {})
if not wanted:
    sys.exit(0)

with tempfile.NamedTemporaryFile(suffix=".plist", delete=False) as tmp:
    path = tmp.name
subprocess.run(["defaults", "export", "com.apple.Terminal", path], check=True)
subprocess.run(["plutil", "-convert", "binary1", path], check=True)

prefs = plistlib.load(open(path, "rb"))
profile = prefs.get("Window Settings", {}).get(name)
if profile is None:
    sys.exit(1)

current = profile.get("keyMapBoundKeys", {})
if current == wanted:
    sys.exit(0)

profile["keyMapBoundKeys"] = wanted
prefs["Window Settings"][name] = profile
plistlib.dump(prefs, open(path, "wb"), fmt=plistlib.FMT_BINARY)
subprocess.run(["defaults", "import", "com.apple.Terminal", path], check=True)
os.unlink(path)
PY
    then
      ok "Scroll key bindings are in sync."
    else
      warn "Could not sync key bindings; re-import $PROFILE_FILE manually."
    fi
  else
    warn "No terminal profile at $PROFILE_FILE"
  fi
else
  warn "Skipping Terminal profile (--no-terminal)."
fi

# ------------------------------------------------------------------
# 5. Optional extras (never fatal)
# ------------------------------------------------------------------
if [[ $DO_EXTRAS == 1 ]]; then
  if command -v pyenv >/dev/null 2>&1 && [[ -z "$(pyenv versions --bare 2>/dev/null)" ]]; then
    info "Installing a baseline python via pyenv..."
    pyenv install -s 3.12 && pyenv global 3.12 || warn "pyenv install failed; skip."
  fi

  if [[ ! -f "$HOME/.cargo/env" ]]; then
    info "Installing Rust (rustup)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
      || warn "rustup install failed; skip."
  fi

  command -v ipython >/dev/null 2>&1 && ipython profile create custom >/dev/null 2>&1 || true
else
  warn "Skipping optional extras (--no-extras)."
fi

# ------------------------------------------------------------------
# 6. Verify everything the config depends on at runtime
# ------------------------------------------------------------------
info "Verifying setup..."
FAILED=0
check() {  # check <label> <test-expression...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    warn "MISSING: $label"
    FAILED=$((FAILED + 1))
  fi
}
have()     { command -v "$1" >/dev/null 2>&1; }
exists()   { [[ -e "$1" ]]; }
linked()   { [[ -L "$1" && "$(readlink "$1")" == "$REPO"/* ]]; }

BP="${HOMEBREW_PREFIX:-/opt/homebrew}"

check "brew"                      have brew
check "eza (every ls alias)"      have eza
check "fzf (fzfinit + ^R)"        have fzf
check "git"                       have git
check "pyenv (pyinit)"            have pyenv
check "zsh-autosuggestions"       exists "$BP/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
check "zsh-syntax-highlighting"   exists "$BP/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
check "powerlevel10k"             exists "$REPO/plugins/powerlevel10k/powerlevel10k.zsh-theme"
check "zsh-z"                     exists "$REPO/plugins/zsh-z/zsh-z.plugin.zsh"
check "fzf-tab"                   exists "$REPO/plugins/fzf-tab/fzf-tab.zsh"
check "gitstatusd (p10k vcs)"     bash -c 'ls "$HOME"/.cache/gitstatus/gitstatusd-* >/dev/null 2>&1'
check "~/.zshrc -> repo"          linked "$HOME/.zshrc"
check "~/.p10k.zsh -> repo"       linked "$HOME/.p10k.zsh"

# p10k is configured with POWERLEVEL9K_MODE=nerdfont-v3, and the Terminal
# profile asks for JetBrainsMonoNLNFM-Light by PostScript name. Without a Nerd
# Font the prompt renders as tofu boxes.
check "JetBrains Mono Nerd Font" bash -c \
  'ls ~/Library/Fonts/JetBrainsMonoNLNerdFontMono-*.ttf /Library/Fonts/JetBrainsMonoNLNerdFontMono-*.ttf 2>/dev/null | grep -q .'

if [[ $FAILED -gt 0 ]]; then
  warn "$FAILED check(s) failed. Re-run without --no-brew, or install the items above."
else
  ok "All checks passed."
fi

printf '\n'
ok "All done!"
cat <<'NEXT'

Next steps:
  1. Fully QUIT Terminal.app (Cmd+Q) and reopen it. This applies the imported
     profile, the JetBrains Mono Nerd Font, and the scroll key bindings.
  2. Powerlevel10k loads automatically. If prompt icons look wrong, confirm the
     profile's font is a Nerd Font (Terminal > Settings > Profiles > Text).
  3. Put anything machine-specific (work paths, proxies) in zsh/local.zsh --
     it is gitignored and sourced last.

Terminal scroll key bindings (from the profile):
  Ctrl+Up/Down                 -> page up/down
  Ctrl+Shift+Up/Down           -> page up/down
  Ctrl+Shift+Alt+Up/Down       -> line up/down
  Ctrl+Shift+Alt+Cmd+Up/Down   -> top / bottom of scrollback

  Ctrl+Up/Down are macOS Mission Control / Application Windows shortcuts by
  default. If they don't scroll, clear them in System Settings > Keyboard >
  Keyboard Shortcuts > Mission Control.
NEXT
