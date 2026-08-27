# Brewfile - everything this shell setup needs.
#   brew bundle --file Brewfile
#
# Regenerate a raw list any time with ./capture.sh (writes Brewfile.generated).

# ~~~~~~~~~~~~~~~~~~ Required by the shell config ~~~~~~~~~~~~~~~~~~~
brew "zsh-autosuggestions"       # sourced by .zshrc
brew "zsh-syntax-highlighting"   # sourced by .zshrc
brew "fzf"                       # fzfinit + ^R history widget
brew "eza"                       # every ls alias, and the fzf-tab previews
brew "git"
brew "bat"                       # better `cat`
brew "tldr"                      # simplified man pages

# ~~~~~~~~~~~~~~~~~~ Fonts (needed for p10k icons + the Terminal profile) ~~~~~~~~~~~~~~~~~~~
cask "font-jetbrains-mono-nerd-font"  # the chaf-dynamic Terminal profile's font
cask "font-meslo-lg-nerd-font"        # Powerlevel10k's recommended fallback

# ~~~~~~~~~~~~~~~~~~ Languages / toolchains ~~~~~~~~~~~~~~~~~~~
brew "pyenv"                     # pyinit
brew "node@22"                   # on PATH in .zshrc
brew "openjdk"
brew "openjdk@17"
brew "openjdk@21"                # JAVA_HOME in .zshrc
brew "ruby"

# ~~~~~~~~~~~~~~~~~~ Dev tooling ~~~~~~~~~~~~~~~~~~~
brew "gh"                        # GitHub CLI
brew "git-lfs"
brew "bazelisk"
brew "direnv"
brew "docker"
brew "cocoapods"
brew "jfrog-cli"
brew "repo"                      # google `repo` tool
brew "mosquitto"                 # MQTT, on PATH in .zshrc
brew "pngpaste"
brew "f3"

# ~~~~~~~~~~~~~~~~~~ Apps ~~~~~~~~~~~~~~~~~~~
cask "alt-tab"
cask "android-commandlinetools"  # ANDROID_HOME in .zshrc
cask "betterdisplay"
cask "copilot-cli"
cask "docker-desktop"
