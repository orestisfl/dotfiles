# Executes commands at login post-zshrc.

export EDITOR=nvim
# NPM packages in homedir
export NPM_PACKAGES="$HOME/.npm-packages"

export PATH=$HOME/bin/exes:$PATH
export PATH=$PATH:/usr/bin/core_perl
# https://wiki.archlinux.org/index.php/Ccache#Enable_for_command_line
export PATH="/usr/lib/ccache/bin/:$PATH"
# Tell our environment about user-installed node tools
export PATH="$PATH:$NPM_PACKAGES/bin"
# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
unset MANPATH  # delete if you already modified MANPATH elsewhere in your configuration
export MANPATH="$NPM_PACKAGES/share/man:$(manpath)"

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
export TERM=linux
