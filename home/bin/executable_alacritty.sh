#!/bin/bash
set -euo pipefail
[[ "${ALACRITTY_SH_DEBUG:-0}" == "1" ]] && set -x

# Populate wm_class, wm_name, parent_pid, focused_marks (Wayland) and win_id (X11)
# for the currently focused window.
probe_focused_window() {
    wm_class=""
    wm_name=""
    parent_pid=""
    win_id=""
    focused_marks=""

    if [[ -n "${SWAYSOCK:-}" ]]; then
        local tree focused
        tree=$(swaymsg -t get_tree)
        focused=$(jq -c '[.. | objects | select(.focused? == true)] | first // {}' <<<"$tree")
        wm_class=$(jq -r '.app_id // .window_properties.class // empty' <<<"$focused")
        wm_name=$(jq -r '.name // empty' <<<"$focused")
        parent_pid=$(jq -r '.pid // empty' <<<"$focused")
        focused_marks=$(jq -r '.marks[]? // empty' <<<"$focused")
    else
        win_id="$(xdotool getactivewindow)"
        wm_class=$(xprop -id "$win_id" WM_CLASS | sed -e 's/.*"\(.*\)"/\1/')
        wm_name=$(xprop -id "$win_id" _NET_WM_NAME 2>/dev/null | sed -e 's/.*"\(.*\)"/\1/' || xprop -id "$win_id" WM_NAME | sed -e 's/.*"\(.*\)"/\1/')
        local xprop_output
        xprop_output=$(xprop -id "$win_id" _NET_WM_PID 2>/dev/null || true)
        [[ "$xprop_output" =~ _NET_WM_PID\(CARDINAL\)\ =\ ([0-9]+) ]] && parent_pid="${BASH_REMATCH[1]}"
    fi
}

alacritty_cwd() {
    if [[ "$wm_name" == "Yazi: "* ]]; then
        local yazi_path yazi_dir
        yazi_path=${wm_name#Yazi: }
        [[ "${yazi_path:0:1}" == "~" ]] && yazi_path="${HOME}${yazi_path#\~}"
        yazi_dir=$(realpath "$yazi_path" 2>/dev/null || true)
        [[ -d "$yazi_dir" ]] && echo "$yazi_dir" && return 0
    fi

    # Wayland: alacritty-sway.zsh marks each window `_<ALACRITTY_WINDOW_ID>`
    # and writes the shell's cwd to a file keyed by the same id.
    if [[ -n "${SWAYSOCK:-}" && -n "$focused_marks" ]]; then
        local mark id cwd_file cwd
        while IFS= read -r mark; do
            [[ "$mark" =~ ^_([0-9]+)$ ]] || continue
            id="${BASH_REMATCH[1]}"
            cwd_file="${XDG_RUNTIME_DIR:-/tmp}/alacritty-cwd/$id"
            [[ -f "$cwd_file" ]] || continue
            IFS= read -r cwd <"$cwd_file" || continue
            [[ -d "$cwd" ]] && echo "$cwd" && return 0
        done <<<"$focused_marks"
    fi

    [[ -n "$parent_pid" ]] || return 1

    # X11: narrow by ALACRITTY_WINDOW_ID. Wayland fallback when the mark/cwd
    # file is missing: first shell under the alacritty process.
    for pid in $(pgrep -P "$parent_pid"); do
        if [[ -n "$win_id" ]]; then
            ps e -p "$pid" 2>/dev/null | grep -q "ALACRITTY_WINDOW_ID=$win_id" || continue
        fi
        local shell_pwd
        shell_pwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
        [[ -d "$shell_pwd" ]] && echo "$shell_pwd" && return 0
    done
    return 1
}

goland_cwd() {
    [[ "$wm_name" == *" – "* ]] || return 1
    local project_name=${wm_name%% – *}
    [[ -n "$project_name" ]] || return 1

    local goland_dir
    goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
    [[ -d "$goland_dir" ]] || return 1
    local recent_projects_file="$goland_dir/options/recentProjects.xml"
    [[ -f "$recent_projects_file" ]] || return 1

    while IFS= read -r path; do
        path=$(echo "$path" | sed "s|\\\$USER_HOME\\\$|$HOME|")
        [[ -d "$path" ]] || continue
        [[ "$(basename "$path")" == "$project_name" ]] && echo "$path" && return 0
    done < <(grep -o 'key="[^"]*"' "$recent_projects_file" | grep "$project_name" | sed -e 's/key="\(.*\)"/\1/')
    return 1
}

cursor_cwd() {
    [[ "$wm_name" == *"- Cursor"* ]] || return 1
    local base_name=${wm_name% - Cursor}
    local project_name=${base_name##* - }
    [[ -n "$project_name" ]] || return 1

    local db_file="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    [[ -f "$db_file" ]] || return 1

    local paths project_path
    paths=$(sqlite3 "$db_file" "SELECT value FROM ItemTable WHERE key = 'history.recentlyOpenedPathsList'" 2>/dev/null | jq -r '.entries[].folderUri | sub("file://"; "")') || return 1
    project_path=$(echo "$paths" | grep "/${project_name}$" | head -n 1)

    [[ -d "$project_path" ]] && echo "$project_path" && return 0
    return 1
}

generic_cwd() {
    [[ -n "$parent_pid" ]] || return 1
    local working_dir
    working_dir=$(realpath "/proc/$parent_pid/cwd" 2>/dev/null || true)
    [[ -d "$working_dir" ]] && echo "$working_dir" && return 0
    return 1
}

get_working_directory() {
    probe_focused_window
    case "$wm_class" in
    "Alacritty") alacritty_cwd ;;
    "jetbrains-goland") goland_cwd ;;
    "Cursor" | "cursor") cursor_cwd ;;
    *) generic_cwd ;;
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
