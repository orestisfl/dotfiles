# Executes commands at login post-zshrc.

export EDITOR=nvim
export VISUAL=nvim

export PATH=$HOME/bin/exes:$PATH
export PATH=$PATH:/usr/bin/core_perl
# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
unset MANPATH  # delete if you already modified MANPATH elsewhere in your configuration

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
export TERM=linux
