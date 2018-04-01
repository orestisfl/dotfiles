#!/bin/bash

function next_mark() {
    i3-msg -t get_marks | python3 -c'
import string
import json

marks = json.loads(input())
for c in string.ascii_lowercase:
    if c not in marks:
        print(c)
        break
' | xargs i3-msg mark
}

if xprop -id $(xdotool getwindowfocus) WM_CLASS | grep -i urxvt
then
    xdotool keyup Return
    xdotool key --clearmodifiers Control_L+Return
else
    exec i3-sensible-terminal
fi

automark="${1-0}"
[[ "$automark" -eq "1" ]] && next_mark
