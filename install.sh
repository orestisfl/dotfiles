#!/bin/bash
set -e
git config --local include.path ../.gitconfig
host=$(hostname -s)
dotfiles="$(dirname -- "$0")"
cd "${dotfiles}"

./stow.sh
./create-alt-links.sh
zenbu "${host}"
