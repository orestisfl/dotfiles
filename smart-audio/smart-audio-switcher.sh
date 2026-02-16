#!/bin/bash

# This single script handles audio device switching for Bluetooth and HDMI.
# It is called by udev rules and logs all output to the systemd journal.
# It uses the card's index for reliability when setting profiles.

# The system username that runs PulseAudio
USER="orestis"
main() {
    # --- CONFIGURATION ---
    # The name pattern of the sound card to control for profile switching.
    SOUND_CARD_NAME_PATTERN="alsa_card.pci-0000_00_1f.3"

    # --- Profile and Sink Names ---
    # These are the full profile names from `pactl list cards`
    HDMI_PROFILE="output:hdmi-stereo+input:analog-stereo"
    HDMI_SINK="alsa_output.pci-0000_00_1f.3.hdmi-stereo"

    ANALOG_PROFILE="output:analog-stereo+input:analog-stereo"
    ANALOG_SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"
    # --- END CONFIGURATION ---

    # Function to run pactl commands with the correct user environment
    run_pactl() {
        local user_id
        user_id=$(id -u "$USER")
        local pulse_socket_path="/run/user/$user_id/pulse"

        if [ ! -S "$pulse_socket_path/native" ]; then
            echo "ERROR: PulseAudio socket not found for user $USER at $pulse_socket_path" >&2
            return 1
        fi

        # Explicitly pass the PULSE_RUNTIME_PATH. Avoid sudo when already the target user
        # (sudo may fail under systemd --user / udev due to missing tty).
        if [ "$(id -un)" = "$USER" ]; then
            PULSE_RUNTIME_PATH="$pulse_socket_path" pactl "$@" 2>&1
        else
            sudo -u "$USER" PULSE_RUNTIME_PATH="$pulse_socket_path" pactl "$@" 2>&1
        fi
    }

    # Wait for a sound card to appear in PulseAudio (with timeout)
    wait_for_sound_card() {
        local max_attempts=15
        local delay=2
        local attempt=1

        while [ $attempt -le $max_attempts ]; do
            if run_pactl list short cards 2>/dev/null | grep -q "$SOUND_CARD_NAME_PATTERN"; then
                return 0
            fi
            echo "Waiting for sound card '$SOUND_CARD_NAME_PATTERN' (attempt $attempt/$max_attempts)..."
            sleep $delay
            ((attempt++))
        done

        echo "ERROR: Sound card '$SOUND_CARD_NAME_PATTERN' not found after ${max_attempts}s" >&2
        return 1
    }

    # Wait for a Bluetooth sink to appear in PulseAudio (with timeout)
    # Returns the sink name in BT_SINK variable if found
    wait_for_bluetooth_sink() {
        local max_attempts=10
        local delay=1
        local attempt=1

        while [ $attempt -le $max_attempts ]; do
            BT_SINK=$(run_pactl list short sinks 2>/dev/null | grep "bluez_output" | awk '{print $2}' | head -n 1)
            if [ -n "$BT_SINK" ]; then
                return 0
            fi
            echo "Waiting for Bluetooth sink (attempt $attempt/$max_attempts)..."
            sleep $delay
            ((attempt++))
        done

        return 1
    }

    # This function decides the best output based on a priority list.
    # Priority: Bluetooth > HDMI > Analog
    update_audio_sink() {
        echo "Updating audio sink based on device priority..."

        # Wait for PulseAudio to be ready with our sound card
        if ! wait_for_sound_card; then
            return 1
        fi

        # 1. Check for Bluetooth devices (Highest Priority)
        local BT_SINK
        BT_SINK=$(run_pactl list short sinks | grep "bluez_output" | awk '{print $2}' | head -n 1)
        if [ -n "$BT_SINK" ]; then
            echo "Found Bluetooth sink: $BT_SINK. Setting as default."
            run_pactl set-default-sink "$BT_SINK"
            return
        fi
        echo "No active Bluetooth sink found."

        # 2. Check for HDMI connection (Second Priority)
        for connector in /sys/class/drm/card*-HDMI-A-*/status; do
            if [ -f "$connector" ] && [ "$(cat "$connector")" == "connected" ]; then
                echo "Found connected HDMI on $connector. Switching to HDMI."
                local card_index
                card_index=$(run_pactl list short cards | grep "$SOUND_CARD_NAME_PATTERN" | awk '{print $1}')

                if [ -z "$card_index" ]; then
                    echo "ERROR: Could not find sound card with pattern '$SOUND_CARD_NAME_PATTERN'" >&2
                    return 1
                fi

                echo "Found sound card '$SOUND_CARD_NAME_PATTERN' at index $card_index."
                run_pactl set-card-profile "$card_index" "$HDMI_PROFILE"
                run_pactl set-default-sink "$HDMI_SINK"
                return
            fi
        done
        echo "No connected HDMI found."

        # 3. Fallback to Analog Speakers (Lowest Priority)
        echo "Falling back to analog speakers."
        local card_index
        card_index=$(run_pactl list short cards | grep "$SOUND_CARD_NAME_PATTERN" | awk '{print $1}')

        if [ -z "$card_index" ]; then
            echo "ERROR: Could not find sound card with pattern '$SOUND_CARD_NAME_PATTERN'" >&2
            return 1
        fi

        echo "Found sound card '$SOUND_CARD_NAME_PATTERN' at index $card_index."
        run_pactl set-card-profile "$card_index" "$ANALOG_PROFILE"
        run_pactl set-default-sink "$ANALOG_SINK"
    }

    # --- MAIN SCRIPT ENTRYPOINT ---
    echo "Script called with:" "$@"

    # For Bluetooth connect events, wait for the sink to appear and switch to it
    if [[ "$1" == "--device-connect" && "$2" == "bluetooth" ]]; then
        if wait_for_bluetooth_sink; then
            echo "Found Bluetooth sink: $BT_SINK. Setting as default."
            run_pactl set-default-sink "$BT_SINK"
            return
        fi
        echo "Bluetooth sink did not appear in time, running normal priority check..."
    fi

    # Any udev event now triggers the same intelligent check, which sets
    # the audio output according to the defined device priority.
    update_audio_sink
}

if [[ -z "$INVOCATION_ID" ]]; then
    CMD=(systemd-run --user --unit smart-audio-switcher -- "$0" "$@")
    if ! sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER")" "${CMD[@]}"; then
        # If the user manager isn't ready yet (early boot/login), don't fail udev.
        echo "WARN: systemd-run --user failed; user session may not be ready yet" >&2
    fi
    exit 0
fi

# Use flock to prevent concurrent runs (race condition from multiple udev events)
LOCK_FILE="/tmp/smart-audio-switcher.lock"
exec {lock_fd}>"$LOCK_FILE"
if ! flock -n "$lock_fd"; then
    echo "Another instance is already running. Exiting."
    exit 0
fi

main "$@"
