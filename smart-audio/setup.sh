#!/bin/bash

# This script installs and configures the smart audio switcher.
# It must be run with root privileges.
# Example: sudo BLUETOOTH_MAC_ADDRESS="xx:xx:xx:xx:xx:xx" bash setup.sh

echo "--- Smart Audio Switcher Setup ---" >&2

# Exit immediately if a command exits with a non-zero status.
set -e

# Change to the script's directory to ensure relative paths work correctly.
cd "$(dirname "$(readlink -f "$0")")"

# Check if running as root, if not, elevate with pkexec.
if [ "$(id -u)" -ne 0 ]; then
	echo "This script requires root privileges. Elevating with pkexec..." >&2
	exec pkexec env BLUETOOTH_MAC_ADDRESS="$BLUETOOTH_MAC_ADDRESS" bash "$(readlink -f "$0")" "$@"
fi

# --- Installation ---

# 1. Copy the unified script to its destination.
echo "Copying smart-audio-switcher.sh to /usr/local/bin/..." >&2
cp ./smart-audio-switcher.sh /usr/local/bin/smart-audio-switcher.sh

# 2. Set the correct ownership and permissions for the script.
echo "Setting ownership (root:root) and permissions (755) on the script..." >&2
chown root:root /usr/local/bin/smart-audio-switcher.sh
chmod 755 /usr/local/bin/smart-audio-switcher.sh

# 3. Process and copy the udev rule to its destination.
if [ -f "./99-smart-audio.rules" ]; then
	# Check for Bluetooth MAC address environment variable
	if [ -z "$BLUETOOTH_MAC_ADDRESS" ]; then
		echo "ERROR: BLUETOOTH_MAC_ADDRESS environment variable is not set." >&2
		echo "Please set it to the MAC address of your Bluetooth device." >&2
		echo "Example: export BLUETOOTH_MAC_ADDRESS=\"8c:f8:c5:c5:33:b0\"" >&2
		exit 1
	fi

	echo "Processing and copying 99-smart-audio.rules to /etc/udev/rules.d/..." >&2
	# Replace the placeholder with the actual MAC address from the env var
	sed "s/__BLUETOOTH_MAC_ADDRESS__/$BLUETOOTH_MAC_ADDRESS/g" ./99-smart-audio.rules >/etc/udev/rules.d/99-smart-audio.rules
else
	echo "WARN: 99-smart-audio.rules not found in current directory. Skipping copy." >&2
	echo "      Ensure it is already in place in /etc/udev/rules.d/" >&2
fi

# 4. Reload udev rules to apply the changes immediately.
echo "Reloading udev rules..." >&2
udevadm control --reload-rules

echo "" >&2
echo "--- Setup Complete ---" >&2
echo "The smart audio switcher has been installed/updated." >&2
echo "You can monitor its logs with: journalctl -f -t smart-audio-switcher" >&2
