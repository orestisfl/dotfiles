#!/bin/bash
# Volume OSD via libnotify; works with dunst (X11) and swaync (Wayland).
set -euo pipefail

human=$(pamixer --get-volume-human)
args=(--expire-time=3000 --replace-id=3710 --hint=string:hlcolor:#b3cfa7)

if [[ "$human" == "muted" ]]; then
    summary="Volume muted"
else
    summary="Volume $human"
    args+=(--hint="int:value:${human%\%}")
fi

notify-send "${args[@]}" "$summary"

pkill -RTMIN+1 i3blocks || true
