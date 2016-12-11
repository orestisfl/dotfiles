#!/bin/bash

# name of the repo and archive name
export BORG_REPO='/media/shared/Backup/borg-ocean'
PREFIX="ocean-of-`hostname`"
DATE="`date +%Y-%m-%d_%H-%M`"
NAME="$PREFIX-$DATE"

echo "Executing borg create:"
# compression lzma is the slowest.
borg create --verbose --stats --show-rc   \
    --exclude *.pyc                       \
    --compression lzma                    \
    --chunker-params 19,23,21,4095        \
    $BORG_REPO::$NAME /media/shared/ocean-files $HOME/semester

echo "Executing borg prune:"
# Use the `prune` subcommand to maintain 3 daily, 4 weekly, 6 monthly and 1 yearly
# archives of THIS machine. --prefix `hostname`- is very important to limit prune's
# operation to this machine's archives and not apply to other machine's archives also.
borg prune --verbose --stats --show-rc \
    --prefix $PREFIX                   \
    --keep-within=2d                   \
    --keep-daily=3                     \
    --keep-weekly=10                   \
    --keep-monthly=20                  \
    --keep-yearly=1                    \
    $BORG_REPO
