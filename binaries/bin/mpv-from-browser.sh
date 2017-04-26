#!/bin/bash
set -e
set -x
browser_class="firefox"

xclip < /dev/null
# Find, focus and type in browser window.
xdotool search --onlyvisible --class "$browser_class" windowfocus key 'ctrl+l'
xdotool key "ctrl+l"
sleep 0.2
xdotool key "ctrl+c"
sleep 0.1
xdotool key "ctrl+w"

# clipboard="$(xclip -selection XA_SECONDARY -o)"
clipboard="$(xclip -o)"
if [ -z "$clipboard" ];
then
    notify-send "Failed to copy"
    exit 1
fi

notify-send "Will try to play $clipboard with mpv"
exec mpv "$clipboard"
