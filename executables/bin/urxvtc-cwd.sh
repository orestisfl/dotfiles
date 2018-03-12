#!/bin/bash
if xprop -id $(xdotool getwindowfocus) WM_CLASS | grep -i urxvt
then
    xdotool keyup Return
    xdotool key --clearmodifiers Control_L+Return
else
    exec i3-sensible-terminal
fi
