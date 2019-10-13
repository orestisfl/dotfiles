#!/bin/sh
export TERM=xterm-256color
export VISUAL=nvim
export TERMINAL=urxvtc
export DESKTOP_SESSION=gnome
# export QT_STYLE_OVERRIDE=GTK+  # Tell Qt to use GTK style
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'
export GTK_OVERLAY_SCROLLING=0
export STEAM_RUNTIME=0

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

source "$HOME/.xinit-local.sh"
cat ~/.i3/include/*.config > ~/.i3/config

~/bin/rand_wall.sh&
urxvtd -q -f -o&  # start urxvtd terminal daemon
numlockx&  # Enable numlock on start.
thunar --daemon&  # Thunar file manager as daemon.
allow_rgb10_configs=false compton --config ~/.config/compton.conf&
# Gnome Keyring Daemon.
eval "$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
export SSH_AUTH_SOCK
guake&
unclutter&  # Hide mouse pointer on inactivity.
( sleep 5; keepassxc& )& # Start password manager.
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1&  # Polkit authentication agent.

exec i3
