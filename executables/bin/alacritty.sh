#!/bin/bash
set -euo pipefail

[[ "$TERMINAL" != "alacritty" ]] && exec "$TERMINAL"

(
    win_id="$(xdotool getactivewindow)"
    parent_pid=$(xprop -id "$win_id" _NET_WM_PID | grep -oP "\d+" | head -n 1)

    # One alacritty process can have multiple windows, each with a different shell in different working directory. Go
    # through each process and if the special ALACRITTY_WINDOW_ID matches the currently focused window id, re-use that
    # directory.
    for pid in $(pgrep -P "$parent_pid"); do
        ps e -p "$pid" | grep "ALACRITTY_WINDOW_ID=$win_id" || continue

        shell_pwd="$(readlink -f /proc/"$pid"/cwd)"
        [[ -d "$shell_pwd" ]] || continue
        exec alacritty msg create-window --working-directory "$shell_pwd"
    done
    false
) || alacritty msg create-window --working-directory "$HOME" || exec alacritty
