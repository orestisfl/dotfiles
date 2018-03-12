#!/bin/bash
set -e

command -v mkvmerge >/dev/null 2>&1 || { zenity --error --text="Please install mkvmerge [mkvtoolnix]"; exit 1; }

xpath=${1%/*}
xbase=${1##*/}
xfext=${xbase##*.}
xpref=${xbase%.*}

output_directory=$(zenity --file-selection --directory --title='Select destination' --filename="$xpath")
echo "$output_directory"

output="$output_directory/$xpref-split.$xfext"
echo "$output"

mkvmerge --split size:3900m "$1" -o "$output" | stdbuf -i0 -o0 -e0 tr '\r' '\n' | stdbuf -i0 -o0 -e0 grep 'Progress:' | stdbuf -i0 -e0 -o0 sed -e 's/Progress: //' -e 's/%//' -e 's/\(....\)\(..\)\(..\)/\1-\2-\3/' | zenity --progress --auto-close --percentage=0 --text="Splitting files..." --title="Splitting files..."
