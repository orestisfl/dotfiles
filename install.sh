#!/bin/bash
set -e
git config --local include.path ../.gitconfig
host=$(hostname -s)
dotfiles="$(dirname -- "$0")"
cd "${dotfiles}"

./stow.sh
./create-alt-links.sh

# Build helper binaries that live in this repo but aren't stowed.
if command -v go >/dev/null 2>&1; then
    mkdir -p "$HOME/bin"
    (
        cd "$dotfiles/skipTaskbar"
        GOBIN="$HOME/bin" go install .
    )
else
    echo "skipTaskbar: go not found; skipping build" >&2
    exit 1
fi
