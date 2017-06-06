#!/bin/bash
export flags="$@"
function check_pdfcrop(){
    local mimetype=$(mimetype --output-format '%m' -M "$1")
    local ret=$?
    if [[  $mimetype == "application/pdf" ]]; then
        pdfcrop $flags "$1" "$1"
    else
        exit "$ret"
    fi
}

export -f check_pdfcrop

find . -type f -print0 | parallel -0 -P0 check_pdfcrop
