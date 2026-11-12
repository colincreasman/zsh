# Windows (PowerShell)

The PowerShell counterpart of the macOS zsh setup: **PowerShell 7 + Oh My Posh** (for
Powerlevel10k), **PSReadLine** (autosuggest, syntax colors, key bindings), **fzf/PSFzf**,
**zoxide** (for zsh-z), `eza`-based `ls`, and a `chaf-dynamic` Windows Terminal profile.

Validated on Windows with PowerShell 7.6: repeat shell-only installs, fresh profile
startup, prompt rendering, quoted-path previews and zoxide completions. Live Windows
Terminal key delivery has not been visually tested.

For just the shell experience (without development applications), run:

```powershell
.\windows\install.ps1 -ShellOnly
```

For WSL, also follow [`../wsl/README.md`](../wsl/README.md).

## Fresh Windows PC, from zero

```powershell
git clone https://github.com/colincreasman/zsh.git $HOME\Personal\Repos\zsh-config
cd $HOME\Personal\Repos\zsh-config\windows; .\install.ps1
```

Then open Windows Terminal, pick the **chaf-dynamic** profile as default, and restart it.
Flags: `-ShellOnly`, `-NoPackages`, `-NoModules`, `-NoTerminal`, `-NoExtras` (skips the `optional` packages).

`install.ps1` is idempotent and:

1. Sets the CurrentUser execution policy to `RemoteSigned` if profiles couldn't load.
2. Installs packages with `winget`, skipping already available shell commands.
   The Nerd Font is installed from upstream into the user's font directory without admin:
   winget's font MSI only supports machine scope. Its verified family name is `JetBrainsMonoNL NFM`.
3. Installs the `PSReadLine`, `PSFzf` and `posh-git` modules.
4. Writes a stub into `Documents\PowerShell\profile.ps1` that dot-sources `windows\profile.ps1`.
   Existing all-host and host-specific profiles are backed up to `*.bak-<timestamp>`.
   Put machine-specific helpers in `local.ps1` before installing; an old host profile
   must not reload afterward and override the shared keys/aliases. Windows PowerShell 5.1 is left alone.
5. Seeds the untracked `local.ps1` from `local.ps1.example`.
6. Drops PowerShell **chaf-dynamic** and **chaf-dynamic WSL** profiles into a JSON
   *fragment* (your `settings.json` is untouched). The WSL profile launches zsh in
   your default distro; install the WSL setup first. New tabs reload environment
   variables so newly installed tools are available.
7. Verifies every dependency and prints a pass/fail list.

## Layout

| Path | zsh twin | What it is |
| --- | --- | --- |
| `profile.ps1` | `home/.zshrc` | Entry point: env, PATH, prompt, zoxide, loads the rest |
| `aliases.ps1` | `zsh/aliases.zsh` | Aliases (as functions: PowerShell aliases can't take args) |
| `functions.ps1` | `zsh/functions.zsh` | `ghash`, `grbours`/`grbtheirs`/`grbog`/`gcfog`/`grsog`, `psls`, `pskill`, `pyinit`, ... |
| `keybindings.ps1` | `setkeybindings` + `fzfinit` | PSReadLine options/colors/keys, tooltip-aware fzf Tab picker |
| `completion-preview.ps1` | fzf-tab previews | `eza` previews, safely decoding quoted paths without evaluation |
| `install-font.ps1` | Homebrew font cask | Per-user Nerd Font installation |
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
| fzf-tab (`eza` previews) | Custom fzf Tab picker with a right-hand `eza` preview; ordinary parameters show their help tooltip. PSFzf's built-in Tab preview does not use completion tooltips. |
| Git command completion | `posh-git` supplies subcommands, options and branches. `git <Tab>` also previews descriptions from the installed Git's help; simple Git shortcuts such as `gc` inherit their underlying command's completion. |
| `Ctrl+R` fzf history | PSFzf `Ctrl+R` (inserts the pick; no ghost-text step) |
| `Ctrl+T` file picker | `Alt+T`, keeping Windows Terminal's `Ctrl+T` new-tab shortcut |
| `Up`/`Down` prefix history | `HistorySearchBackward/Forward` (edits the buffer, doesn't ghost it) |
| `Ctrl+Space` / `Opt+Space` accept | `Ctrl+Space` whole suggestion / `Alt+Space` one word (`Ctrl+Alt+Right` fallback if Windows claims Alt+Space). Plain Space always types a space. |
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

Paste `terminal/actions.snippet.jsonc` into Terminal's actions to enable scroll
shortcuts and release suggestion/redo chords to the shells. The installer does not
change your default profile or global keybindings; select the default in Terminal Settings.

Tab uses PowerShell's registered command/parameter completers before its normal
filesystem fallback. Functions with parameter completers keep their specific
candidates and descriptions. Other native CLIs need their PowerShell completer
registered; zsh completion scripts cannot be reused directly. Only directory
candidates get `eza` previews, so a command/branch name matching a local directory
does not replace its help preview with a file listing.

The post-fzf prompt redraw temporarily uses UTF-8, matching Oh My Posh's own
redraw handling, then restores the previous console encoding. This prevents
the prompt gutters/status glyphs turning into `?` on legacy Windows code pages.

Not ported (Mac-only): Homebrew/MacPorts paths, `.vimrc`, Karabiner/Cmd-Q tweaks, Terminal.app
key map. `fzf` isn't wired to `Alt+C` (it's the copy key, as on the Mac).

## Keeping it in sync

Same as the Mac: the stub points into the repo, so editing `windows\*.ps1` *is* editing the live
profile (`src` to reload). Commit from the repo. Windows Terminal edits made in its UI live in
`settings.json`; copy anything you want to keep into `terminal\chaf-dynamic.json`.

## Validation

```powershell
pwsh -NoLogo -NoProfile -File .\windows\tests.ps1
```

Tests use temporary directories and an isolated zoxide database. They cover spaces
and apostrophes in previews, parameter tooltips, real zoxide completion, Git
subcommands/help/branches/options, Git shortcuts, function completers and Space/Tab bindings.
Noninteractive `pwsh -Command`/`-File` startup skips console-only setup.

An optional headless Windows console regression (requires `pywinpty`) exercises
the real Git/fzf popup, description preview, selection, cancel and Unicode prompt
redraw with code page 437:

```powershell
python .\windows\interactive-tests.py
```

It opens an isolated pseudoconsole, not your working Terminal tabs, and keeps
test history in a temporary directory.
