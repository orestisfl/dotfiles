#!/bin/sh
export EDITOR=vim
export VISUAL=vim
export TERMINAL=urxvtc

# NPM packages in homedir
export NPM_PACKAGES="$HOME/.npm-packages"

# Tell our environment about user-installed node tools
export PATH="$NPM_PACKAGES/bin:$PATH"
# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
unset MANPATH  # delete if you already modified MANPATH elsewhere in your configuration
export MANPATH="$NPM_PACKAGES/share/man:$(manpath)"

# Tell Node about these packages
export NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

source ~/.xinit-local.sh
$HOME/bin/generate-i3-config.sh

# random wallpaper
~/bin/rand_wall.sh &
# start urxvtd terminal daemon
urxvtd -q -f -o&
# Keyboard layout.
setxkbmap -model pc105 -layout us,gr -option grp:alt_shift_toggle &
# Numlock on start.
numlockx &
# Conky.
conky&
# Thunar file manager as daemon.
thunar --daemon&
# Compton.
compton --config ~/.config/compton.conf -b&
# Gnome Keyring Daemon.
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
# Start guake terminal.
guake&
xset m 0 0&
# Auto-lock after some time.
xautolock -locker '~/bin/lock.sh' -time ${AUTOLOCK_TIME}&
# Auto-lock after suspend. https://wiki.archlinux.org/index.php/Power_management#xss-lock
xss-lock -- "$HOME/bin/lock.sh"&
# Hide mouse pointer on inactivity.
unclutter&
# Bind extra mouse buttons.
xbindkeys&
~/bin/watch-tumbler.sh&

exec i3
