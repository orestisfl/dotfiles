#!/bin/bash
set -e
ignore_match="##.*$"

to_stow=""
for dir in *; do
    [ -d "${dir}" ] && [ ! -e "${dir}/.nostow" ] && to_stow+="${dir} "
done

stow -v -R --ignore="${ignore_match}" $to_stow
