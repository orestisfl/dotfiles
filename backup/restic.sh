#!/bin/bash
set -euo pipefail

history_repo_dir="$HOME/Documents/history-backup"
backup_exclude_file="$HOME/Documents/backup-exclude"

# Optional lightweight history snapshot.
if [[ -d "$history_repo_dir/.git" ]]; then
    (
        cd "$history_repo_dir"
        pacman -Qqe >pkg-list || true
        modprobed-db list >/tmp/modprobed-list && mv /tmp/modprobed-list ./ || true
        cp -f "$HOME/.zhistory" zsh-history
        git add .
        git commit --no-gpg-sign -m "$(date)" || true
    )
fi

# Skip backup on metered connections.
if command -v nmcli >/dev/null && [[ $(nmcli -g METERED general) == yes* ]]; then
    echo 'metered connection, skipping backup'
    exit 1
fi

# Fail fast if the secret is locked or another backup is running.
if [[ $(secret-tool search backup restic 2>&1 >/dev/null) == *'Cannot get secret of a locked object'* ]]; then
    echo 'keyring locked'
    exit 1
fi
if pidof restic >/dev/null; then
    echo 'restic already running'
    exit 1
fi

port=8123
rclone serve restic --addr "localhost:$port" -v gdrive:backup &
rclone_pid="$!"
trap 'kill "$rclone_pid" 2>/dev/null || true' EXIT

for _ in {1..30}; do
    nc -z localhost "$port" && break
    sleep 1
done
nc -z localhost "$port"

export RESTIC_REPOSITORY="rest:http://localhost:$port/"
export RESTIC_PASSWORD_COMMAND='secret-tool lookup backup restic'

restic unlock

# Exit code 3: snapshot saved, but some files could not be read.
restic backup \
    --verbose \
    --one-file-system \
    --exclude-caches \
    --exclude-file="$backup_exclude_file" \
    ~ /etc || [[ $? -eq 3 ]]

# shellcheck disable=SC2046 # word-splits into the two snapshot IDs
restic diff $(restic --json snapshots --host "$HOSTNAME" | jq -r '.[-2:][].id') || true

restic forget --prune \
    --keep-within-hourly 2d \
    --keep-within-daily 31d \
    --keep-within-weekly 6m \
    --keep-within-monthly 5y \
    --keep-within-yearly 100y
