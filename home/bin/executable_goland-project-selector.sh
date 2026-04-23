#!/usr/bin/env bash
set -euo pipefail

GOLAND_BIN="$HOME/.local/share/JetBrains/Toolbox/apps/goland/bin/goland"

# Find the latest GoLand config directory
goland_dir=$(find ~/.config/JetBrains -maxdepth 1 -type d -name "GoLand*" | sort -V | tail -n 1)
[[ -d "$goland_dir" ]] || {
    notify-send --urgency=critical "GoLand Launcher" "No GoLand config directory found"
    exit 1
}

recent_projects_file="$goland_dir/options/recentProjects.xml"
[[ -f "$recent_projects_file" ]] || {
    notify-send --urgency=critical "GoLand Launcher" "recentProjects.xml not found"
    exit 1
}

# 12 months ago in milliseconds
twelve_months_ago=$((($(date +%s) - 365 * 24 * 60 * 60) * 1000))

# Parse project entries from XML
projects=()
current_path=""
current_timestamp=""
is_hidden=false

while IFS= read -r line; do
    if [[ "$line" =~ entry\ key=\"([^\"]+)\" ]]; then
        current_path="${BASH_REMATCH[1]}"
        current_timestamp=""
        is_hidden=false
    fi

    if [[ "$line" =~ hidden=\"true\" ]]; then
        is_hidden=true
    fi

    if [[ "$line" =~ name=\"activationTimestamp\"\ value=\"([^\"]+)\" ]]; then
        current_timestamp="${BASH_REMATCH[1]}"
    fi

    if [[ "$line" =~ \</entry\> ]]; then
        if [[ -n "$current_path" && -n "$current_timestamp" && "$is_hidden" == false ]]; then
            resolved_path="${current_path//\$USER_HOME\$/$HOME}"

            if [[ "$resolved_path" != *'$APPLICATION'* ]] &&
                ((current_timestamp >= twelve_months_ago)) &&
                [[ -d "$resolved_path" ]]; then
                projects+=("${current_timestamp}|${resolved_path}")
            fi
        fi
        current_path=""
    fi
done <"$recent_projects_file"

if ((${#projects[@]} == 0)); then
    notify-send "GoLand Launcher" "No recent projects found (last 12 months)"
    exit 1
fi

# Sort by activationTimestamp descending (most recent first)
IFS=$'\n' sorted=($(printf '%s\n' "${projects[@]}" | sort -t'|' -k1 -rn))
unset IFS

# Build rofi display list and a parallel path lookup array
paths=()
display=""
for entry in "${sorted[@]}"; do
    path="${entry#*|}"
    name=$(basename "$path")
    short_path="${path/#$HOME/\~}"
    display+="${name}  ${short_path}"$'\n'
    paths+=("$path")
done
display="${display%$'\n'}"

# Open rofi (-format i returns the 0-based index of the selected line)
selected=$(echo "$display" | rofi -dmenu -i -p "GoLand" -format i \
    -theme-str 'window {width: 50%;}')

[[ -z "$selected" ]] && exit 0

project_path="${paths[$selected]}"

exec "$GOLAND_BIN" "$project_path"
