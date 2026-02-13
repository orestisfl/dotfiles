#!/bin/bash
set -euo pipefail
[[ "${ALACRITTY_SH_DEBUG:-0}" == "1" ]] && set -x

get_working_directory() {
    win_id="$(xdotool getactivewindow)"
    wm_class=$(xprop -id "$win_id" WM_CLASS | sed -e 's/.*"\(.*\)"/\1/')

    case "$wm_class" in
    "Alacritty")
        # Check for Yazi windows - extract directory from window title
        wm_name=$(xprop -id "$win_id" _NET_WM_NAME 2>/dev/null | sed -e 's/.*"\(.*\)"/\1/' || xprop -id "$win_id" WM_NAME | sed -e 's/.*"\(.*\)"/\1/')
        if [[ "$wm_name" == "Yazi: "* ]]; then
            yazi_path=${wm_name#Yazi: }
            # Expand ~ if present
            [[ "${yazi_path:0:1}" == "~" ]] && yazi_path="${HOME}${yazi_path#\~}"
            yazi_dir=$(realpath "$yazi_path" 2>/dev/null)
            [[ -d "$yazi_dir" ]] && echo "$yazi_dir" && return 0
        fi

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
        wm_name=$(xprop -id "$win_id" WM_NAME | sed -e 's/.*"\(.*\)"/\1/')
        [[ "$wm_name" == *" – "* ]] || return 1
        project_name=${wm_name%% – *}
        [[ -n "$project_name" ]] || return 1

        goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
        [[ -d "$goland_dir" ]] || return 1
        recent_projects_file="$goland_dir/options/recentProjects.xml"
        [[ -f "$recent_projects_file" ]] || return 1

        # Extract all project paths from entry keys and find one where basename matches project name
        while IFS= read -r path; do
            path=$(echo "$path" | sed "s|\\\$USER_HOME\\\$|$HOME|")
            [[ -d "$path" ]] || continue
            basename=$(basename "$path")
            [[ "$basename" == "$project_name" ]] && echo "$path" && return 0
        done < <(grep -o 'key="[^"]*"' "$recent_projects_file" | grep "$project_name" | sed -e 's/key="\(.*\)"/\1/')
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
        xprop_output=$(xprop -id "$win_id" _NET_WM_PID 2>/dev/null)
        [[ "$xprop_output" =~ _NET_WM_PID\(CARDINAL\)\ =\ ([0-9]+) ]] || return 0
        pid="${BASH_REMATCH[1]}"
        working_dir=$(realpath "/proc/$pid/cwd" 2>/dev/null)
        [[ -d "$working_dir" ]] && echo "$working_dir" && return 0
        return 1
        ;;
    esac
}

working_dir=$(get_working_directory) && [[ -d "$working_dir" ]] || working_dir="$HOME"

cmd="${1:-alacritty}"
if [[ "$cmd" == "alacritty" ]]; then
    alacritty msg create-window --working-directory "$working_dir" || exec alacritty --working-directory "$working_dir"
elif [[ "$cmd" == "yazi" ]]; then
    alacritty msg create-window --working-directory "$working_dir" --command "$SHELL" -c "zsh -is run_yazi" ||
        exec alacritty --working-directory "$working_dir" -e "$SHELL" -c "zsh -is run_yazi"
else
    read -r -a cmd_array <<<"$cmd"
    cd "$working_dir" && exec "${cmd_array[@]}"
fi
