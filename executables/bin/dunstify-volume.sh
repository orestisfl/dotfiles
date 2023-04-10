#!/bin/bash
set -euo pipefail

volume=$(pamixer --get-volume-human)
dunstify --timeout=3000 --replace=3710 -h "int:value:$volume" -h 'string:hlcolor:#b3cfa7' "$volume"
pkill -RTMIN+1 i3blocks
