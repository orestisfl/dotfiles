#!/bin/bash
# Taken from: https://github.com/TheLocehiliosan/yadm/blob/05ed83ea34b1062f39e89a689ce85e1295b72aad/yadm#L101-L142
set -e
match_system=$(uname -s)
match_host=$(hostname -s)
match_user=$(id -u -n)
match="^(.+)##($match_system|$match_system.$match_host|$match_system.$match_host.$match_user|())$"

working_dir=${WORK_DIR:-"$HOME/dotfiles"}
target_dir=${TARGET_DIR:-"$HOME"}
cd "${working_dir}"

last_linked=''
for tracked_file in $(git ls-files | sort); do
    #; process both the path, and its parent directory
    for alt_path in "$tracked_file" "${tracked_file%/*}"; do
        if [ -e "$alt_path" ]; then
            if [[ $alt_path =~ $match ]]; then
                if [ "$alt_path" != "$last_linked" ]; then
                    alt_path="${working_dir}"/"${alt_path}"
                    new_link="${BASH_REMATCH[1]}"
                    new_link="${target_dir}"/"${new_link#*/}"
                    echo "Linking $alt_path to $new_link"
                    ln -nfs "$alt_path" "$new_link"
                    last_linked="$alt_path"
                fi
            fi
        fi
    done
done
