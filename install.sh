#!/bin/bash
set -e
host=$(hostname -s)
dotfiles="$(dirname -- "$0")"
cd "${dotfiles}"

./stow.sh
./create-alt-links.sh
zenbu "${host}"
