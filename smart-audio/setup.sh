#!/bin/bash

# This script installs and configures the smart audio switcher.
# It must be run with root privileges.
# Example: sudo BLUETOOTH_MAC_ADDRESS="xx:xx:xx:xx:xx:xx" bash setup.sh

echo "--- Smart Audio Switcher Setup ---"

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root. Please use sudo." >&2
	exit 1
fi

# --- Installation ---

# 1. Copy the unified script to its destination.
echo "Copying smart-audio-switcher.sh to /usr/local/bin/"...
cp ./smart-audio-switcher.sh /usr/local/bin/smart-audio-switcher.sh

# 2. Set the correct ownership and permissions for the script.
echo "Setting ownership (root:root) and permissions (755) on the script..."
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

	echo "Processing and copying 99-smart-audio.rules to /etc/udev/rules.d/"...
	# Replace the placeholder with the actual MAC address from the env var
	sed "s/__BLUETOOTH_MAC_ADDRESS__/$BLUETOOTH_MAC_ADDRESS/g" ./99-smart-audio.rules >/etc/udev/rules.d/99-smart-audio.rules
else
	echo "WARN: 99-smart-audio.rules not found in current directory. Skipping copy."
	echo "      Ensure it is already in place in /etc/udev/rules.d/"
fi

# 4. Reload udev rules to apply the changes immediately.
echo "Reloading udev rules"...
udevadm control --reload-rules

echo ""
echo "--- Setup Complete ---"
echo "The smart audio switcher has been installed/updated."
echo "You can monitor its logs with: journalctl -f -t smart-audio-switcher"
