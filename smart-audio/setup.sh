#!/bin/bash

# Installs and configures the smart audio switcher. Requires root.

echo "--- Smart Audio Switcher Setup ---" >&2

set -e

cd "$(dirname "$(readlink -f "$0")")"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Elevating with pkexec..." >&2
    exec pkexec bash "$(readlink -f "$0")" "$@"
fi

echo "Copying smart-audio-switcher.sh to /usr/local/bin/..." >&2
cp ./smart-audio-switcher.sh /usr/local/bin/smart-audio-switcher.sh

echo "Setting ownership (root:root) and permissions (755) on the script..." >&2
chown root:root /usr/local/bin/smart-audio-switcher.sh
chmod 755 /usr/local/bin/smart-audio-switcher.sh

if [ -f "./99-smart-audio.rules" ]; then
    echo "Copying 99-smart-audio.rules to /etc/udev/rules.d/..." >&2
    cp ./99-smart-audio.rules /etc/udev/rules.d/99-smart-audio.rules
else
    echo "WARN: 99-smart-audio.rules not found in current directory. Skipping copy." >&2
    echo "      Ensure it is already in place in /etc/udev/rules.d/" >&2
fi

echo "Reloading udev rules..." >&2
udevadm control --reload-rules

echo "" >&2
echo "--- Setup Complete ---" >&2
echo "The smart audio switcher has been installed/updated." >&2
echo "You can monitor its logs with: journalctl --user -f --user-unit smart-audio-switcher.service" >&2
