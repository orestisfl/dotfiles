#!/bin/bash
set -e
include_path="${include_path:-$HOME/.i3/include/}"
i3_config="$HOME/.i3/config"
i3_themes="$HOME/.i3/themes"

rm -f "$i3_config"
for f in "${include_path}"*.config
do
    cat "${f}" >> "${i3_config}"
done

random_style=$(find "$i3_themes/" -type f | shuf -n 1)
i3-style "${random_style}" -o "${i3_config}"
