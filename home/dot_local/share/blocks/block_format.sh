#!/usr/bin/env bash

BLOCK_COLOR_WARNING=${BLOCK_COLOR_WARNING:-#f0c674}
BLOCK_COLOR_CRITICAL=${BLOCK_COLOR_CRITICAL:-#cc6666}

# i3blocks sets BLOCK_NAME; ironbar doesn't.
block_output_is_i3blocks() {
    [[ -n "${BLOCK_NAME:-}" ]]
}

block_escape_markup() {
    local text=${1//&/"&amp;"}
    text=${text//</"&lt;"}
    text=${text//>/"&gt;"}
    printf '%s' "${text}"
}

block_output_emit() {
    local full=${1}
    local short=${2:-${full}}

    if block_output_is_i3blocks; then
        printf '%s\n%s\n\n' "${full}" "${short}"
    else
        printf '%s\n' "${full}"
    fi
}

block_output_emit_urgent() {
    local full=${1}
    local short=${2:-${full}}
    local color=${3:-${BLOCK_COLOR_CRITICAL}}

    if block_output_is_i3blocks; then
        block_output_emit "${full}" "${short}"
        return 33
    fi

    printf '<span foreground="%s">%s</span>\n' \
        "${color}" \
        "$(block_escape_markup "${full}")"
}
