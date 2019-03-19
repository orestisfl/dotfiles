#!/bin/bash

first=true
while read URL; do
    if [ "$first" = true ]; then
        first=false
        firefox -new-window "$URL"
    else
        firefox "$URL"
    fi
done < "$1"
