#!/bin/bash
set -e

# name of the repo and archive name
BORG_REPO='/media/shared/Backup/borg'
PREFIX="home-of-$(hostname)"
DATE=$(date +%Y-%m-%d_%H-%M)
NAME="$PREFIX-$DATE"

echo "Executing borg create:"
# compression lzma is the slowest.
borg create --verbose --stats --show-rc   \
    --exclude "*.pyc"                     \
    --exclude /home/*/.cache              \
    --exclude /home/*/.gvfs/              \
    --exclude /home/*/.local/share/Trash/ \
    --exclude /home/*/.thumbnails/        \
    --exclude /home/*/.PlayOnLinux/       \
    --exclude /home/*/.local/share/Steam/ \
    --exclude /home/*/.AMD/               \
    --exclude /home/*/.wine/              \
    --exclude /home/*/swapfile            \
    --compression lzma                    \
    --chunker-params 19,23,21,4095        \
    $BORG_REPO::"$NAME" "$HOME"

echo "Executing borg prune:"
# Use the `prune` subcommand to maintain 3 daily, 4 weekly, 6 monthly and 1 yearly
# archives of THIS machine. --prefix `hostname`- is very important to limit prune's
# operation to this machine's archives and not apply to other machine's archives also.
borg prune --verbose --stats --show-rc \
    --prefix "$PREFIX"                 \
    --keep-within=2d                   \
    --keep-daily=3                     \
    --keep-weekly=10                   \
    --keep-monthly=20                  \
    --keep-yearly=1                    \
    $BORG_REPO

source "$HOME/bin/backup-ocean.sh"
