#!/usr/bin/env bash

BLOCK_COLOR_WARNING=${BLOCK_COLOR_WARNING:-#f0c674}
BLOCK_COLOR_CRITICAL=${BLOCK_COLOR_CRITICAL:-#cc6666}

block_output_mode() {
    if [[ -n "${_BLOCK_OUTPUT_MODE_CACHE:-}" ]]; then
        printf '%s\n' "${_BLOCK_OUTPUT_MODE_CACHE}"
        return 0
    fi

    case "${BLOCK_OUTPUT_MODE:-}" in
    i3blocks | xorg)
        _BLOCK_OUTPUT_MODE_CACHE=i3blocks
        ;;
    ironbar | plain | wayland)
        _BLOCK_OUTPUT_MODE_CACHE=ironbar
        ;;
    *)
        if [[ -n "${BLOCK_NAME:-}" ]]; then
            _BLOCK_OUTPUT_MODE_CACHE=i3blocks
        else
            _BLOCK_OUTPUT_MODE_CACHE=ironbar
        fi
        ;;
    esac

    printf '%s\n' "${_BLOCK_OUTPUT_MODE_CACHE}"
}

block_output_is_i3blocks() {
    [[ "$(block_output_mode)" == "i3blocks" ]]
}

block_escape_markup() {
    local text=${1//&/&amp;}
    text=${text//</&lt;}
    text=${text//>/&gt;}
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
