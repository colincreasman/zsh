#!/usr/bin/env bash
# capture.sh - pull live macOS state that ISN'T a symlink back into this repo.
#
# The dotfiles in home/ and zsh/ are symlinked into $HOME by install.sh, so
# editing them already edits the repo -- nothing to capture there. This script
# handles the two things that live outside the filesystem:
#
#   1. the active Terminal.app profile (stored in macOS defaults)
#   2. the current Homebrew package list (written to Brewfile.generated)
#
# Run it after tweaking Terminal settings or installing packages, then commit.

set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }

info "Exporting the active Terminal.app profile..."
python3 - "$REPO" <<'PY'
import plistlib, sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path.home() / "Library/Preferences/com.apple.Terminal.plist"
data = plistlib.load(src.open('rb'))
name = data['Default Window Settings']
profile = dict(data['Window Settings'][name])

out = repo / "terminal" / f"{name}.terminal"
out.parent.mkdir(parents=True, exist_ok=True)
# Binary plist on purpose: keyMapBoundKeys hold raw ESC bytes that XML can't encode.
with out.open('wb') as f:
    plistlib.dump(profile, f, fmt=plistlib.FMT_BINARY, sort_keys=False)
print(f"  exported {out.name} ({out.stat().st_size} bytes), profile='{name}'")
PY

info "Regenerating the raw Homebrew package list..."
if command -v brew >/dev/null 2>&1; then
  {
    echo "# Brewfile.generated - raw output of \`brew leaves\` + \`brew list --cask\`."
    echo "# Reference only; the curated Brewfile is the source of truth."
    echo "# Generated $(date)"
    echo
    brew leaves | sed 's/^/brew "/; s/$/"/'
    echo
    brew list --cask | sed 's/^/cask "/; s/$/"/'
  } > "$REPO/Brewfile.generated"
  echo "  wrote Brewfile.generated - diff it against Brewfile"
else
  warn "brew not found; skipping package list."
fi

info "Done. Review with: git -C \"$REPO\" status && git -C \"$REPO\" diff"
