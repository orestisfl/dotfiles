#!/bin/bash
set -euo pipefail

get_working_directory() {
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
			ps e -p "$pid" | grep "ALACRITTY_WINDOW_ID=$win_id" >/dev/null || continue

			shell_pwd="$(readlink -f /proc/"$pid"/cwd)"
			[[ -d "$shell_pwd" ]] && echo "$shell_pwd" && return 0
		done
		return 1
		;;
	"jetbrains-goland")
		goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
		[[ -d "$goland_dir" ]] || return 1
		recent_projects_file="$goland_dir/options/recentProjects.xml"
		[[ -f "$recent_projects_file" ]] || return 1
		project_path=$(grep 'lastOpenedProject' "$recent_projects_file" | sed -e 's/.*value="\(.*\)".*/\1/' | sed "s|\\\$USER_HOME\\\$|$HOME|")
		[[ -d "$project_path" ]] && echo "$project_path" && return 0
		return 1
		;;
	"Cursor" | "cursor")
		wm_name=$(xprop -id "$win_id" WM_NAME | sed -e 's/.*"\(.*\)"/\1/')

		[[ "$wm_name" == *"- Cursor"* ]] || return 1
		base_name=${wm_name% - Cursor}
		project_name=${base_name##* - }
		[[ -n "$project_name" ]] || return 1

		db_file="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
		[[ -f "$db_file" ]] || return 1

		# Query the Cursor database for a JSON list of recently opened paths.
		# 1. `sqlite3`: Executes a SQL query to get the JSON blob containing recent paths.
		# 2. `jq`: Parses the JSON, extracts the `folderUri` for each entry, and removes the "file://" prefix.
		paths=$(sqlite3 "$db_file" "SELECT value FROM ItemTable WHERE key = 'history.recentlyOpenedPathsList'" 2>/dev/null | jq -r '.entries[].folderUri | sub("file://"; "")')
		project_path=$(echo "$paths" | grep "/${project_name}$" | head -n 1)

		[[ -d "$project_path" ]] && echo "$project_path" && return 0
		return 1
		;;
	*)
		return 1
		;;
	esac
}

working_dir=$(get_working_directory) && [[ -d "$working_dir" ]] || working_dir="$HOME"

cmd="${1:-alacritty}"
if [[ "$cmd" == "alacritty" ]]; then
	alacritty msg create-window --working-directory "$working_dir" || exec alacritty
elif [[ "$cmd" == "yazi" ]]; then
	tmp="$(mktemp -t "yazi-cwd.XXXXXX")"

	# Build command string with proper quoting
	yazi_cmd="yazi"
	[[ $# -gt 1 ]] && yazi_cmd+=" $(printf '%q ' "${@:2}")"
	yazi_cmd+=" --cwd-file=$(printf '%q' "$tmp"); IFS= read -r -d '' cwd < $(printf '%q' "$tmp"); [ -n \"\$cwd\" ] && [ \"\$cwd\" != \"\$PWD\" ] && builtin cd -- \"\$cwd\"; rm -f -- $(printf '%q' "$tmp"); exec \${SHELL:-bash} -i"

	alacritty msg create-window --working-directory "$working_dir" --command "$SHELL" -c "$yazi_cmd" ||
		exec alacritty --working-directory "$working_dir" -e "$SHELL" -c "$yazi_cmd"
else
	read -r -a cmd_array <<<"$cmd"
	cd "$working_dir" && exec "${cmd_array[@]}"
fi
