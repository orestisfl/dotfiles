#!/bin/bash
set -e
echoerr() { echo "$@" 1>&2; }

new_value="${1:-0}"
xinput_device=$(xinput list | grep -i "synaptics touchpad" | head -n 1)
regex="id=([0-9]*)"
if [[ $xinput_device =~ $regex ]]; then
    id="${BASH_REMATCH[1]}"
    echoerr Matched $id.

    xinput_prop=$(xinput list-props "${id}" | grep -i "Horizontal Scroll")
    regex="\(([0-9]*)\)"

    if [[ $xinput_prop =~ $regex ]]; then
        prop_id="${BASH_REMATCH[1]}"
        echoerr Matched prop id $prop_id.

        xinput set-prop $id $prop_id $new_value
        echoerr Prop $prop_id of device $id was set to $new_value.
    else
        echoerr Failed to match prop_id.
        exit 1
    fi
else
    echoerr Failed to match device id.
    exit 1
fi
