#!/bin/sh
export VISUAL=nvim
export TERMINAL=alacritty
export DESKTOP_SESSION=gnome
export XDG_SESSION_TYPE=x11
# export QT_STYLE_OVERRIDE=GTK+  # Tell Qt to use GTK style
export GTK_OVERLAY_SCROLLING=0
#export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dawt.useSystemAAFontSettings=gasp -Dsun.java2d.xrender=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'
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

# Apply Xft defaults and optional local overrides (mutable; used by toggle_dpi).
if [ -f "$HOME/.config/xft.xres" ]; then
    xrdb -merge "$HOME/.config/xft.xres"
fi
if [ -f "$HOME/.config/xft.local.xres" ]; then
    xrdb -merge "$HOME/.config/xft.local.xres"
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

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
[[ -f "$HOME/.xinit-local" ]] && source "$HOME/.xinit-local"

numlockx&  # Enable numlock on start.
unclutter&  # Hide mouse pointer on inactivity.

systemd-cat -t polkit-mate-authentication-agent /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &
keepassxc&

setxkbmap -layout us,gr -option 'grp:alt_shift_toggle' -option 'compose:ralt' -option 'caps:escape'
alttab -mk Super_L -kk grave -w 1 -d 1 &
trash-empty -f 30&

# Start graphical-session.target (via x11-session.target) for X11 services
systemctl --user import-environment DISPLAY XAUTHORITY
systemctl --user start --no-block x11-session.target

exec i3
