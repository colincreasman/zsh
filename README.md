# zsh-config

My complete macOS shell setup: zsh + [Powerlevel10k](https://github.com/romkatv/powerlevel10k),
fzf-driven completion and history, an `eza`-based `ls`, and the `chaf-dynamic`
Terminal.app profile.

## Fresh Mac, from zero

```sh
git clone https://github.com/colincreasman/zsh.git ~/zsh-config
cd ~/zsh-config && ./install.sh
```

Then **quit Terminal.app entirely (⌘Q) and reopen it.** That's it.

The repo can be cloned anywhere — `.zshrc` resolves its own location through
the symlink, so no paths need editing.

## What `install.sh` does

1. Installs Homebrew if missing, then everything in `Brewfile`
   (including the Nerd Fonts the prompt and Terminal profile need).
2. Clones `powerlevel10k`, `zsh-z` and `fzf-tab` into `plugins/` (gitignored).
3. Pre-fetches **`gitstatusd`**, the daemon behind Powerlevel10k's git segment.
   It isn't bundled with the p10k repo, so without this the first prompt either
   stalls downloading it or errors with *"gitstatus failed to initialize"*.
4. Symlinks every file in `home/` into `$HOME`. Existing real files are moved to
   `<file>.bak-<timestamp>` first — nothing is ever deleted.
5. Imports `terminal/chaf-dynamic.terminal` and makes it the default profile.
6. Best-effort extras: a baseline pyenv Python, rustup, the ipython `custom`
   profile used by the `ipy` alias.
7. **Verifies every runtime dependency** and prints a pass/fail list, so you find
   out immediately instead of via a broken prompt.

It is idempotent — re-run it any time to pick up changes or update plugins.
Flags: `--no-brew`, `--no-terminal`, `--no-extras`.

## Why it works out of the box

The prompt has three dependencies that aren't just "clone a repo", and each is
handled automatically:

| Requirement | Why | Handled by |
| --- | --- | --- |
| `gitstatusd` binary | Powers the `vcs` (git) prompt segment; not shipped in the p10k clone | Pre-fetched in step 3 |
| A Nerd Font | `.p10k.zsh` sets `POWERLEVEL9K_MODE=nerdfont-v3`, and the Terminal profile requests `JetBrainsMonoNLNFM-Light` by name — without it icons render as tofu boxes | `font-jetbrains-mono-nerd-font` + `font-meslo-lg-nerd-font` in the `Brewfile` |
| `zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf`, `eza` | Sourced/called directly by `.zshrc` and the aliases | `Brewfile` |

`zsh-z`, `fzf-tab` and `powerlevel10k` are plain git clones (step 2).
`compinit` runs with `-i` so a fresh Mac's group-writable Homebrew directories
can't block your first shell on an interactive prompt.

## Layout

| Path | What it is |
| --- | --- |
| `home/` | Dotfiles symlinked into `$HOME` (`.zshrc`, `.zshenv`, `.zprofile`, `.p10k.zsh`, `.vimrc`) |
| `zsh/aliases.zsh` | All aliases — git, eza/ls, navigation |
| `zsh/functions.zsh` | Functions and ZLE widgets — ghost-text history, `pyinit`, `fzfinit`, `setkeybindings` |
| `zsh/local.zsh` | **Not tracked.** Machine-specific config, sourced last |
| `terminal/` | Exported Terminal.app profile |
| `plugins/` | **Not tracked.** Cloned by `install.sh` |
| `Brewfile` | Curated package list |
| `install.sh` / `capture.sh` | Apply the repo to a Mac / pull live state back into the repo |

## Machine-specific config

Anything that shouldn't be public — work paths, corporate proxies, private SDK
locations — goes in `zsh/local.zsh`, which is gitignored and sourced at the end
of `.zshrc`. `zsh/local.zsh.example` shows the pattern; `install.sh` seeds a copy
if you don't already have one. Edit it with `l,`.

## Keeping the repo in sync

The dotfiles are symlinks, so editing `~/.zshrc` *is* editing the repo — just
commit. Two things live outside the filesystem and need `./capture.sh`:

```sh
./capture.sh   # re-exports the Terminal profile + writes Brewfile.generated
```

Diff `Brewfile.generated` against `Brewfile` when you've installed new packages.

## Key bindings

Set by `setkeybindings` in `zsh/functions.zsh`:

| Keys | Action |
| --- | --- |
| `Up` / `Down` | Browse history as dim ghost text, filtered by what's typed — the real buffer is never touched |
| `Ctrl+R` | fzf over history; the pick returns as a ghost suggestion |
| `Ctrl+Space` | Accept the whole suggestion |
| `Opt+Space` | Accept one word |
| `Ctrl+X` | Expand the alias under the cursor |
| `Opt+-` | Redo |

`setkeybindings classic` restores plain fzf-history behavior live, no reload needed.

From the Terminal profile:

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+Up/Down` | Page up/down |
| `Ctrl+Shift+Opt+Up/Down` | Line up/down |
| `Ctrl+Shift+Opt+Cmd+Up/Down` | Top / bottom of scrollback |

## Handy aliases

`z,` `a,` `f,` `l,` open `.zshrc` / aliases / functions / local config in the
editor; `zc` cds to this repo; `src` reloads the shell.
