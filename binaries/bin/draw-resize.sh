#!/bin/bash
set -e -x

# Example: resize the focused window:
# draw-resize.sh $(xdotool getactivewindow)

window_id="${1:-$(xwininfo | grep 'id: 0x' | grep -Eo '0x[a-z0-9]+')}"

read -r X Y W H < <(slop -f "%x %y %w %h" && echo)

i3-msg "[id=$window_id]" floating enable, resize set "$W" "$H", move to position "$X" px "$Y" px
