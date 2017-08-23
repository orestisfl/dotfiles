#!/bin/bash
if xprop -id $(xdotool getwindowfocus) WM_CLASS | grep -i urxvt
then
    xdotool key Control_L+Return
else
    i3-sensible-terminal
fi
