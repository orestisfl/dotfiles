#!/bin/bash -e
old=$(xkb-switch)
xkb-switch -s us
i3lock -t -n -i $(find ~/.local/share/lock-images -type f | shuf -n 1)
xkb-switch -s "$old"
