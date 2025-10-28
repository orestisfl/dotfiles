#!/bin/bash
set -euo pipefail

[[ "$TERMINAL" != "alacritty" ]] && exec "$TERMINAL"

(
	win_id="$(xdotool getactivewindow)"
	wm_class=$(xprop -id "$win_id" WM_CLASS | sed -e 's/.*"\(.*\)"/\1/')

	case "$wm_class" in
	"Alacritty")
		xprop_output=$(xprop -id "$win_id" _NET_WM_PID)
		[[ "$xprop_output" =~ _NET_WM_PID\(CARDINAL\)\ =\ ([0-9]+) ]] && parent_pid="${BASH_REMATCH[1]}"

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
		;;
	"jetbrains-goland")
		goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
		[[ -d "$goland_dir" ]]
		recent_projects_file="$goland_dir/options/recentProjects.xml"
		[[ -f "$recent_projects_file" ]]
		project_path=$(grep 'lastOpenedProject' "$recent_projects_file" | sed -e 's/.*value="\(.*\)".*/\1/' | sed "s|\\\$USER_HOME\\\$|$HOME|")
		[[ -d "$project_path" ]]
		exec alacritty msg create-window --working-directory "$project_path"
		;;
	"Thunar")
		# Handle later
		;;
	*)
		false
		;;
	esac
) || alacritty msg create-window --working-directory "$HOME" || exec alacritty
