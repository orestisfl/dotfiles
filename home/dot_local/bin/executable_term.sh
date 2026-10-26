#!/bin/bash
set -euo pipefail
[[ "${TERM_SH_DEBUG:-0}" == "1" ]] && set -x

# Populate wm_class, wm_name, parent_pid, focused_marks for the currently focused window.
probe_focused_window() {
    wm_class="" wm_name="" parent_pid="" focused_marks=""

    local msg win_id
    if [[ -n "${SWAYSOCK:-}" ]]; then
        msg=swaymsg
    elif command -v i3-msg >/dev/null 2>&1; then
        msg=i3-msg
        win_id=$(xdotool getactivewindow 2>/dev/null) || true
    else
        return 0
    fi

    eval "$("$msg" -t get_tree | jq -r --argjson w "${win_id:-null}" '
        first(.. | objects | select(if $w then .window? == $w else .focused? == true end)) // {}
        | @sh "wm_class=\(.app_id // .window_properties.class // "")",
          @sh "wm_name=\(.name // "")",
          @sh "parent_pid=\(.pid // "")",
          @sh "focused_marks=\(.marks // [] | join("\n"))"')"
}

ghostty_cwd() {
    if [[ "$wm_name" == "Yazi: "* ]]; then
        local yazi_path=${wm_name#Yazi: } yazi_dir
        yazi_dir=$(realpath "${yazi_path/#\~/"$HOME"}" 2>/dev/null || true)
        [[ -d "$yazi_dir" ]] && echo "$yazi_dir" && return 0
    fi

    # ghostty-wm.zsh marks each window `_<id>` and writes the shell's cwd to a file keyed by the same id.
    local mark cwd_file cwd
    while IFS= read -r mark; do
        [[ "$mark" =~ ^_(.+)$ ]] || continue
        cwd_file="${XDG_RUNTIME_DIR:-/tmp}/ghostty-cwd/${BASH_REMATCH[1]}"
        [[ -f "$cwd_file" ]] || continue
        IFS= read -r cwd <"$cwd_file" || continue
        [[ -d "$cwd" ]] && echo "$cwd" && return 0
    done <<<"$focused_marks"

    # No mark (e.g. `ghostty -e zsh -c ...`, which ghostty-wm.zsh skips). A
    # ghostty process owning a single child is one window: use that child's cwd.
    [[ -n "$parent_pid" ]] || return 1
    local children
    children=$(pgrep -P "$parent_pid") || return 1
    [[ "$children" == *$'\n'* ]] && return 1
    realpath "/proc/$children/cwd" 2>/dev/null
}

goland_cwd() {
    [[ "$wm_name" == *" – "* ]] || return 1
    local project_name=${wm_name%% – *}
    [[ -n "$project_name" ]] || return 1

    local goland_dir recent_projects_file path
    goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
    recent_projects_file="$goland_dir/options/recentProjects.xml"
    [[ -f "$recent_projects_file" ]] || return 1

    while IFS= read -r path; do
        path=${path/\$USER_HOME\$/"$HOME"}
        [[ "${path##*/}" == "$project_name" && -d "$path" ]] && echo "$path" && return 0
    done < <(grep -oP 'key="\K[^"]*' "$recent_projects_file")
    return 1
}

cursor_cwd() {
    [[ "$wm_name" == *"- Cursor"* ]] || return 1
    local base_name=${wm_name% - Cursor}
    local project_name=${base_name##* - }
    [[ -n "$project_name" ]] || return 1

    local db_file="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    [[ -f "$db_file" ]] || return 1

    sqlite3 "$db_file" "SELECT value FROM ItemTable WHERE key = 'history.recentlyOpenedPathsList'" 2>/dev/null |
        jq -r --arg p "/$project_name" \
            'first(.entries[].folderUri // empty | sub("^file://"; "") | select(endswith($p)))'
}

generic_cwd() {
    [[ -n "$parent_pid" ]] && realpath "/proc/$parent_pid/cwd" 2>/dev/null
}

get_working_directory() {
    probe_focused_window
    case "$wm_class" in
    "com.mitchellh.ghostty") ghostty_cwd ;;
    "jetbrains-goland") goland_cwd ;;
    "Cursor" | "cursor") cursor_cwd ;;
    *) generic_cwd ;;
    esac
}

working_dir=$(get_working_directory) && [[ -d "$working_dir" ]] || working_dir="$HOME"

cmd="${1:-ghostty}"
case "$cmd" in
ghostty) args=() ;;
yazi) args=(-e "$SHELL" -is run_yazi) ;;
*)
    read -r -a cmd_array <<<"$cmd"
    cd "$working_dir"
    exec "${cmd_array[@]}"
    ;;
esac
ghostty +new-window --working-directory="$working_dir" "${args[@]}" ||
    exec ghostty --working-directory="$working_dir" "${args[@]}"
