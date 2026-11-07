# Agent handoff: finish the Windows PowerShell setup

You are picking this up on Colin's **Windows PC**. The setup was written and tested on his Mac
(PowerShell 7 on macOS), **never run on real Windows**. Your job: run it, fix what breaks, and
get it to feel like his Mac zsh setup.

## Goal

Cloning this repo and running `windows\install.ps1` should give the Mac experience in PowerShell 7:
Oh My Posh prompt, inline history suggestions, syntax colors, fzf history and Tab completion with
`eza` previews, zoxide `z<Tab>` previews, the git aliases, and the `chaf-dynamic` Windows Terminal
profile. Read `windows/README.md` first: it has the layout and the Mac -> Windows mapping.

## Setup on this PC

```powershell
winget install Git.Git          # if git is missing; reopen the terminal
git clone https://github.com/colincreasman/zsh.git $HOME\Personal\Repos\zsh-config
cd $HOME\Personal\Repos\zsh-config
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Then close and reopen the terminal and run `install.ps1` again: new tools only reach PATH in a
new session, so the first run's verify list may show false "missing".

## Rules for this repo and user

- Remote `origin` is `git@github.com:colincreasman/zsh.git`, branch `main`. History uses the
  email `ccreasma@ford.com`; don't change git identity or config.
- Commit only when asked. One-line subjects, 10-59 chars, imperative, sentence case, backticks
  around code identifiers, no trailing period, no body, no AI attribution trailers.
- Push `git push -u origin main:main` after a fetch; never force, never merge main back in.
  On this PC the default git/gh credentials may be the work account: if the push is refused,
  stop and give Colin the commands to run under his personal credentials.
- `windows/local.ps1` and `zsh/local.zsh` are untracked, machine-specific: never commit them.
- Don't touch the Mac side (`home/`, `zsh/`, `install.sh`) unless asked.

## Known unknowns to verify first (all unproven on Windows)

1. **winget IDs** in `windows/packages.json`. `install.ps1` reports failures and carries on. For
   each one run `winget search <name>` and fix the id. Least certain: `GitHub.Copilot`,
   `tldr-pages.tlrc`, `Bazel.Bazelisk`, `JFrog.JFrogCLI`, `rhysd.actionlint`,
   `DEVCOM.JetBrainsMonoNerdFont`, `Android.PlatformTools`, `direnv.direnv`.
2. **Nerd Font face name** in `windows/terminal/chaf-dynamic.json`: `JetBrainsMonoNL Nerd Font Mono`,
   weight light. Check the installed family name (Settings > Personalization > Fonts) and fix it.
   The Mac profile uses `JetBrainsMonoNLNFM-Light`.
3. **Windows Terminal fragment**: confirm the `chaf-dynamic` profile appears after a restart.
   If it doesn't, check the fragment folder `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\zsh-config`
   and the JSON schema (the profile needs `name`, `guid`, `commandline`).
4. **PSFzf Tab preview**: `keybindings.ps1` expects PSFzf's `-TabExpansion` preview pane to show
   each completion's tooltip (we fill tooltips with an `eza` listing). Confirm it does for `cd <Tab>`
   and `z <Tab>`. If not, look at PSFzf's docs/source for how the preview is built and adapt.
5. **Prompt**: `windows/chaf.omp.json` is a hand-built approximation of `home/.p10k.zsh` (path,
   status, time, git on line 2, `╭─ ╰─` gutters). Compare it against the Mac look and tune it.
   Validate with `oh-my-posh config export` / `oh-my-posh debug` if the theme fails to load.
6. **Key bindings** (`Set-ShellKeyBindings`): check Ctrl+Space, Alt+Space, Alt+C, Ctrl+X, Ctrl+Shift+Z,
   Alt+- and that the removed kill keys (Ctrl+D, Ctrl+K/U/W, Esc, Ctrl+Home/End) really are unbound.
   Windows Terminal may claim some chords itself (Ctrl+Shift+Z, Alt+Space = window menu).
7. **Windows PowerShell 5.1**: the stubs also cover `WindowsPowerShell\`, but the profile is
   designed for PowerShell 7. Check 5.1 loads quietly (or drop its stub from `install.ps1`).
8. Run the whole profile with `pwsh` and confirm no red errors at startup, then time it
   (`Measure-Command { pwsh -NoLogo -Command exit }`); trim anything slow.

## What was tested already (on macOS pwsh 7.6)

All `*.ps1` parse with zero errors; JSON files are valid; `ghash`, `glog-dir` (all options),
date normalization, `Add-PathEntry`, command definitions, and the path/`z` argument completers
(including tooltips) behave. PSReadLine option/key setup applied without errors in a PTY.
Not testable on the Mac: winget, the registry toggle in `swbg`, Windows paths, Windows Terminal,
the Nerd Font, real `fzf`/`zoxide`/`oh-my-posh` interplay.

## Design decisions to keep

- PowerShell aliases can't take arguments, so every alias is a function. Names are
  case-insensitive, hence `gcM` -> `gcnv`, `grbC` -> `grbac`; comma aliases `z,` `a,` `f,` `l,` ->
  `ep` `ea` `ef` `el`. `gc`, `gcm`, `ls` shadow built-in aliases and are removed at load.
- The profile stub in `Documents\PowerShell\profile.ps1` just dot-sources `windows\profile.ps1`
  (no symlinks, so no admin/Developer Mode needed). Editing the repo edits the live profile.
- Windows Terminal is configured via a JSON *fragment*, never by editing `settings.json`.
- Interactive-only setup is guarded by `$Host.Name -eq 'ConsoleHost'` so `pwsh -Command` stays quiet.

## Not ported on purpose

Homebrew/MacPorts, `.vimrc`, Karabiner/Cmd-Q tweaks, Terminal.app key map, the `Ctrl+R` ghost-text
step (PSFzf inserts the pick), true ghost-text Up/Down browsing (PSReadLine edits the buffer).
Ideas if Colin wants them: a custom PSReadLine handler for ghost-text history; PSFzf `Alt+C`.

## Definition of done

`install.ps1` runs clean twice in a row; a new Windows Terminal tab opens straight into the
`chaf-dynamic` profile with the prompt, colors, icons, suggestions, `Ctrl+R`, `cd <Tab>` and
`z <Tab>` previews all working; fixes committed in small one-line commits and pushed to `main`;
`windows/README.md` updated with anything that turned out different (and the "not yet run on a
real Windows PC" note removed).
