# WSL (Ubuntu/Debian)

Run from the checkout inside WSL, as your Linux user:

```sh
bash wsl/install.sh
```

The repo can stay on the Windows drive; plugins and Linux binaries live in
`~/.local/share/zsh-config` and `~/.local/bin` for speed and Linux permissions.
The installer installs Linux shell dependencies with `sudo apt-get`, then clones
Powerlevel10k, zsh-z, fzf-tab, autosuggestions and syntax highlighting. Recent fzf
and eza binaries come from their upstream releases (Ubuntu 22.04's fzf is too old).
Existing dotfiles are backed up, not deleted. Re-running leaves installed tools alone.
`--no-packages` skips apt; `--default-shell` optionally runs `chsh`.

The Linux entry point reuses **the actual Mac prompt, aliases, widgets and fzf
preview settings**, including ghost-text Up/Down history and zsh-z-ranked `z<Tab>`.
Only `~/.zshrc` and `~/.p10k.zsh` are linked; Bash, login files and project tools
are left intact. Put Linux-specific overrides in the ignored `wsl/local.zsh`.
Windows' clipboard is used by `pb`/`pbp`/`ghash` and Alt+C; `o` opens Windows
files/URLs. These require WSL Windows interop and `pwsh.exe` on the inherited PATH.
VS Code's Windows/WSL launcher supplies `code --wait`.

From Windows run `windows\install.ps1 -NoPackages -NoModules` to install matching
Windows Terminal styling, then pick **chaf-dynamic WSL** from the tab menu.
It launches `wsl.exe --cd ~ --exec zsh -l` in your default distro. Add
`-d <distro>` in Terminal Settings to choose a different one. Run
`windows\install-font.ps1` if the Nerd Font is not already installed on **Windows**.
The configured Terminal shortcuts apply to both shells. If Windows intercepts
Alt+Space, Alt+Right also accepts the next suggestion word in zsh.

AirDrop, macOS appearance switching and Terminal.app integrations are not ported.
No Mac history is imported, so history and zsh-z learn your WSL commands/directories
independently. No Git identity, credentials or development toolchains are changed.

## Validation

Tested in Ubuntu 22.04 on WSL2, including repeat installs and a real interactive
PTY test (independent of your working Terminal tabs):

```sh
zsh -lic 'source /path/to/repo/wsl/tests.zsh'
python3 wsl/interactive-tests.py  # needs python3-pexpect
```

The interactive test uses isolated history/directory databases. It checks zsh-z
candidates from outside the target directories, visible `eza` previews, selection,
prefix-filtered ghost history without changing the buffer, and Ctrl+Space acceptance.
The Linux entry point explicitly registers zsh-z's completer after compinit and
uses the candidate word when fzf-tab does not provide file metadata.
