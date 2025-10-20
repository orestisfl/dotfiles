#!/bin/sh
export VISUAL=nvim
export TERMINAL=alacritty
export DESKTOP_SESSION=gnome
# export QT_STYLE_OVERRIDE=GTK+  # Tell Qt to use GTK style
export GTK_OVERLAY_SCROLLING=0
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dawt.useSystemAAFontSettings=gasp -Dsun.java2d.xrender=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'
export GTK_THEME='Materia-dark-compact'

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
unclutter&  # Hide mouse pointer on inactivity.

systemd-cat -t polkit-mate-authentication-agent /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &
keepassxc&
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"

setxkbmap -layout us,gr -option 'grp:alt_shift_toggle' -option 'compose:ralt' -option 'caps:escape'
alttab -mk Super_L -kk grave -w 1 -d 1 &
systemd-cat -t thunar -- thunar --daemon &
trash-empty -f 30&

exec i3
