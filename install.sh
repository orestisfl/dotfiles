#!/bin/bash
# Bootstrap dotfiles: render ~/.config/chezmoi/chezmoi.toml, install
# pre-commit hooks, then `chezmoi apply`.

set -euo pipefail

dotfiles_dir="$(cd -- "$(dirname -- "$0")" >/dev/null && pwd)"
cd "${dotfiles_dir}"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi: not found. Install it first, e.g.:" >&2
    echo "    sudo pacman -S chezmoi" >&2
    echo "    # or: sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- -b \"\$HOME/.local/bin\"" >&2
    exit 1
fi

# Re-run this after editing home/.chezmoi.toml.tmpl to refresh role flags.
chezmoi init --source="${dotfiles_dir}"

if command -v pre-commit >/dev/null 2>&1; then
    (cd "${dotfiles_dir}" && pre-commit install --install-hooks) || true
fi

chezmoi apply --verbose "$@"
