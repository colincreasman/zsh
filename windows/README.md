# Windows (PowerShell)

The PowerShell counterpart of the macOS zsh setup: **PowerShell 7 + Oh My Posh** (for
Powerlevel10k), **PSReadLine** (autosuggest, syntax colors, key bindings), **fzf/PSFzf**,
**zoxide** (for zsh-z), `eza`-based `ls`, and a `chaf-dynamic` Windows Terminal profile.

> Written and parse/behavior-tested on macOS with PowerShell 7; not yet run on a real
> Windows PC. Expect to tweak winget IDs and the font face name on first install.

## Fresh Windows PC, from zero

```powershell
git clone https://github.com/colincreasman/zsh.git $HOME\Personal\Repos\zsh-config
cd $HOME\Personal\Repos\zsh-config\windows; .\install.ps1
```

Then open Windows Terminal, pick the **chaf-dynamic** profile as default, and restart it.
Flags: `-NoPackages`, `-NoModules`, `-NoTerminal`, `-NoExtras` (skips the `optional` packages).

`install.ps1` is idempotent and:

1. Sets the CurrentUser execution policy to `RemoteSigned` if profiles couldn't load.
2. Installs everything in `packages.json` with `winget` (the `Brewfile` equivalent, incl. the Nerd Font).
3. Installs the `PSReadLine` and `PSFzf` modules.
4. Writes a one-line stub into `Documents\PowerShell\profile.ps1` (and `WindowsPowerShell\`) that
   dot-sources `windows\profile.ps1`. Existing profiles are moved to `*.bak-<timestamp>`.
5. Seeds the untracked `local.ps1` from `local.ps1.example`.
6. Drops the Windows Terminal profile in as a JSON *fragment* (your `settings.json` is untouched).
7. Verifies every dependency and prints a pass/fail list.

## Layout

| Path | zsh twin | What it is |
| --- | --- | --- |
| `profile.ps1` | `home/.zshrc` | Entry point: env, PATH, prompt, zoxide, loads the rest |
| `aliases.ps1` | `zsh/aliases.zsh` | Aliases (as functions: PowerShell aliases can't take args) |
| `functions.ps1` | `zsh/functions.zsh` | `ghash`, `grbours`/`grbtheirs`/`grbog`/`gcfog`/`grsog`, `psls`, `pskill`, `pyinit`, ... |
| `keybindings.ps1` | `setkeybindings` + `fzfinit` | PSReadLine options/colors/keys, fzf + completion previews |
| `git-dirlog.ps1` | `zsh/git-dirlog.sh` | `glog-dir` (same options), `gld`, `gldf` |
| `chaf.omp.json` | `home/.p10k.zsh` | Oh My Posh theme: path + status/time on line 1, `❯` + git on line 2 |
| `packages.json` | `Brewfile` | winget packages + PowerShell modules |
| `terminal/chaf-dynamic.json` | `terminal/chaf-dynamic.terminal` | Windows Terminal profile + color scheme (decoded from the Terminal.app profile) |
| `terminal/actions.snippet.jsonc` | profile key map | Scroll bindings to paste into `settings.json` |
| `local.ps1` | `zsh/local.zsh` | **Not tracked.** Machine-specific config, loaded last |

The profile resolves its own location, so the repo can live anywhere.

## What carries over, and what changed

| macOS | Windows |
| --- | --- |
| Powerlevel10k | Oh My Posh (`chaf.omp.json`) |
| zsh-autosuggestions | PSReadLine `InlineView` prediction from history, same color (xterm 131, standout) |
| zsh-syntax-highlighting | PSReadLine `-Colors`, same xterm-256 numbers |
| zsh-z | zoxide; `z<Tab>` lists zoxide's own ranked matches in fzf, previewing each with `eza` |
| fzf-tab (`eza` previews) | PSFzf `-TabExpansion` with a right-hand preview; path commands show the same `eza` listing |
| `Ctrl+R` fzf history | PSFzf `Ctrl+R` (inserts the pick; no ghost-text step) |
| `Up`/`Down` prefix history | `HistorySearchBackward/Forward` (edits the buffer, doesn't ghost it) |
| `Ctrl+Space` / `Opt+Space` accept | `Ctrl+Space` whole suggestion / `Alt+Space` one word |
| `Ctrl+X` expand alias | `Ctrl+X` (expands aliases and the one-line function shortcuts) |
| `Opt+C` copy selection/rest | `Alt+C` (selection or cursor-to-end; can't include the grey suggestion) |
| `Shift+arrows` selection | PSReadLine's built-in `Shift`/`Ctrl+Shift`+arrows |
| `Ctrl+Z` undo (set up in zsh) | native: `Ctrl+Z` undo, `Ctrl+Shift+Z`/`Ctrl+Y`/`Alt+-` redo |
| kill-word/line, `Ctrl+D`, Esc-clears-line unbound | `Ctrl+D`, `Ctrl+K/U/W`, `Alt+D`, `Ctrl+Home/End`, `Esc`, `Ctrl+Del` unbound; `Ctrl+Backspace`/`Alt+Backspace` keep word-delete |
| `pbcopy` / `pbpaste` / `open` | `Set-Clipboard` / `Get-Clipboard` / `Invoke-Item` (`pb`, `pbp`, `o`) |
| `exec zsh` (`src`) | starts a fresh `pwsh` and exits the old one |
| `swbg` | toggles the Windows app/system light-dark registry flags |

Renames forced by PowerShell: names are case-insensitive, so `gcM` -> `gcnv` and `grbC` -> `grbac`;
the comma aliases `z,` `a,` `f,` `l,` -> `ep` `ea` `ef` `el` (plus `ek` for keybindings);
`gc`, `gcm` and `ls` shadow built-in aliases (removed at load). Everything else keeps its name.

Not ported (Mac-only): Homebrew/MacPorts paths, `.vimrc`, Karabiner/Cmd-Q tweaks, Terminal.app
key map. `fzf` isn't wired to `Alt+C` (it's the copy key, as on the Mac).

## Keeping it in sync

Same as the Mac: the stub points into the repo, so editing `windows\*.ps1` *is* editing the live
profile (`src` to reload). Commit from the repo. Windows Terminal edits made in its UI live in
`settings.json`; copy anything you want to keep into `terminal\chaf-dynamic.json`.
