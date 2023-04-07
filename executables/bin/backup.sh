#!/bin/bash
set -euo pipefail

export BORG_REPO="$HOME/Documents/history-backup"
export BORG_PASSPHRASE=""

pacman -Qqe > ~/Documents/pkg-list

borg create \
    --show-rc \
    --stats \
    --verbose \
    --one-file-system \
    ::'{hostname}-{now}' \
    ~/.zhistory ~/Documents/pkg-list || {
    retcode=$?
    echo "$retcode"
    [[ $retcode -eq 0 ]] || [[ $retcode -eq 1 ]] || exit $retcode
}
