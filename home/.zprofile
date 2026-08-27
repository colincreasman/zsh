# .zprofile - sourced for login shells, before .zshrc.

# MacPorts, if it happens to be installed on this machine.
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
