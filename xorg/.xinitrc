#!/bin/sh
export VISUAL=nvim
export TERMINAL=gnome-terminal
export DESKTOP_SESSION=gnome
# export QT_STYLE_OVERRIDE=GTK+  # Tell Qt to use GTK style
export GTK_OVERLAY_SCROLLING=0

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

[[ -f "$HOME/.xinit-local" ]] && source "$HOME/.xinit-local"

numlockx&  # Enable numlock on start.
thunar --daemon&  # Thunar file manager as daemon.
unclutter&  # Hide mouse pointer on inactivity.
/usr/lib/mate-polkit/polkit-mate-authentication-agent-1&  # Polkit authentication agent.
keepassxc&
eval "$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
export SSH_AUTH_SOCK

exec i3
