#
# Executes commands at login post-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

## Execute code that does not affect the current session in the background.
#{
#  # Compile the completion dump to increase startup speed.
#  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
#  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
#    zcompile "$zcompdump"
#  fi
#} &!
#
## Print a random, hopefully interesting, adage.
#if (( $+commands[fortune] )); then
#  if [[ -t 0 || -t 1 ]]; then
#    fortune -s
#    print
#  fi
#fi

export EDITOR=vim
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

export PIP_USER=yes
export PYTHONUSERBASE="$HOME/.pythonuserbase"

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
export TERM=linux
