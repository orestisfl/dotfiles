#!/bin/bash
set -e
host=$(hostname -s)
dotfiles="$(dirname -- "$0")"

"${dotfiles}"/stow.sh
"${dotfiles}"/create-alt-links.sh
zenbu "${host}"
