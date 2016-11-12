#!/bin/bash
set -e
I3_INCLUDE_PATH="${I3_INCLUDE_PATH:-$HOME/.i3/include/}"
I3_CONFIG="$HOME/.i3/config"

rm $I3_CONFIG
for f in "${I3_INCLUDE_PATH}"*.config
do
    cat "${f}" >> "${I3_CONFIG}"
done

random_style=$(ls $NPM_PACKAGES/lib/node_modules/i3-style/themes | shuf -n 1)
i3-style "${random_style}" -o "${I3_CONFIG}"
