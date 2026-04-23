#!/bin/bash

# Handles audio routing for this machine by udev events.
# Priority: Bluetooth > HDMI monitor matching $HDMI_MONITOR_NAME > laptop speakers.
# Invoked from /etc/udev/rules.d/99-smart-audio.rules and re-execs itself into a
# transient --user systemd unit so output lands in the user journal.

USER="orestis"

main() {
    # Matches both the legacy ACP name and the UCM name for the onboard card.
    SOUND_CARD_NAME_PATTERN="alsa_card.pci-0000_00_1f.3"
    SINK_PREFIX="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"

    # Matched against each HDMI port's device.product.name (from the monitor's
    # ELD). Stable across GPU port swaps, unlike HDMIN indices.
    HDMI_MONITOR_NAME="LG"

    SPEAKER_PROFILE="HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)"
    SPEAKER_SINK="${SINK_PREFIX}.HiFi__Speaker__sink"

    # Substring patterns for preferred mic sources, in priority order. Using a
    # stable tail (e.g. "HiFi__Mic1__source") survives card renames. Monitor
    # sources (".monitor") are always excluded.
    KNOWN_GOOD_MIC_PATTERNS=(
        "HiFi__Mic1__source"
    )

    USER_ID=$(id -u "$USER")
    RUNTIME_DIR="/run/user/$USER_ID"
    IS_TARGET_USER=$([ "$(id -un)" = "$USER" ] && echo true || echo false)

    run_as_user() {
        if $IS_TARGET_USER; then
            "$@" 2>&1
        else
            sudo -u "$USER" "$@" 2>&1
        fi
    }

    run_pactl() {
        if [ ! -S "$RUNTIME_DIR/pulse/native" ]; then
            echo "ERROR: PulseAudio socket not found at $RUNTIME_DIR/pulse" >&2
            return 1
        fi
        run_as_user env PULSE_RUNTIME_PATH="$RUNTIME_DIR/pulse" pactl "$@"
    }

    # Resolve a sink's PipeWire object.id (wpctl's ID space) from its name.
    # `pactl list short sinks` returns object.serial, which diverged from
    # object.id in recent pipewire releases.
    get_sink_object_id() {
        local sink_name="$1"
        run_pactl list sinks 2>/dev/null | awk -v target="$sink_name" '
            function flush() {
                if (found && id && !result) result = id
                id = ""; found = 0
            }
            /^Sink #/ { flush() }
            /[[:space:]]node\.name = / {
                if (match($0, /"[^"]*"/)) {
                    if (substr($0, RSTART+1, RLENGTH-2) == target) found = 1
                }
            }
            /[[:space:]]object\.id = / {
                if (match($0, /"[^"]*"/)) id = substr($0, RSTART+1, RLENGTH-2)
            }
            END { flush(); if (result) print result }
        '
    }

    # Move sink-inputs from $from_sink to $to_sink (both by name). Streams
    # routed to any other sink are left alone, as a best-effort heuristic for
    # preserving manual routing (PipeWire has no "pinned" flag we can read).
    move_streams_from_to() {
        local from_sink="$1" to_sink="$2"
        [ -z "$from_sink" ] || [ "$from_sink" = "$to_sink" ] && return 0

        local from_id
        from_id=$(run_pactl list short sinks 2>/dev/null |
            awk -v n="$from_sink" '$2==n {print $1; exit}')
        [ -z "$from_id" ] && return 0

        local ids id
        ids=$(run_pactl list short sink-inputs 2>/dev/null |
            awk -v s="$from_id" '$2==s {print $1}')
        [ -z "$ids" ] && return 0

        for id in $ids; do
            if run_pactl move-sink-input "$id" "$to_sink" >/dev/null 2>&1; then
                echo "Moved sink-input #$id: $from_sink -> $to_sink"
            else
                echo "WARN: Failed to move sink-input #$id to $to_sink" >&2
            fi
        done
    }

    set_default_sink() {
        local sink_name="$1"
        local prev_default
        prev_default=$(run_pactl get-default-sink 2>/dev/null | tr -d '[:space:]')

        run_pactl set-default-sink "$sink_name"

        local node_id
        node_id=$(get_sink_object_id "$sink_name")
        if [ -n "$node_id" ]; then
            run_as_user env XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-default "$node_id"
            echo "Set WirePlumber default to node $node_id ($sink_name)."
        else
            echo "WARN: Could not resolve node ID for sink '$sink_name', wpctl default not set." >&2
        fi

        # Migrate streams from the previous default so audio follows the route.
        move_streams_from_to "$prev_default" "$sink_name"
    }

    # Source counterpart of get_sink_object_id.
    get_source_object_id() {
        local source_name="$1"
        run_pactl list sources 2>/dev/null | awk -v target="$source_name" '
            function flush() {
                if (found && id && !result) result = id
                id = ""; found = 0
            }
            /^Source #/ { flush() }
            /[[:space:]]node\.name = / {
                if (match($0, /"[^"]*"/)) {
                    if (substr($0, RSTART+1, RLENGTH-2) == target) found = 1
                }
            }
            /[[:space:]]object\.id = / {
                if (match($0, /"[^"]*"/)) id = substr($0, RSTART+1, RLENGTH-2)
            }
            END { flush(); if (result) print result }
        '
    }

    # Source counterpart of move_streams_from_to.
    move_source_outputs_from_to() {
        local from_source="$1" to_source="$2"
        [ -z "$from_source" ] || [ "$from_source" = "$to_source" ] && return 0

        local from_id
        from_id=$(run_pactl list short sources 2>/dev/null |
            awk -v n="$from_source" '$2==n {print $1; exit}')
        [ -z "$from_id" ] && return 0

        local ids id
        ids=$(run_pactl list short source-outputs 2>/dev/null |
            awk -v s="$from_id" '$2==s {print $1}')
        [ -z "$ids" ] && return 0

        for id in $ids; do
            if run_pactl move-source-output "$id" "$to_source" >/dev/null 2>&1; then
                echo "Moved source-output #$id: $from_source -> $to_source"
            else
                echo "WARN: Failed to move source-output #$id to $to_source" >&2
            fi
        done
    }

    set_default_source() {
        local source_name="$1"
        local prev_default
        prev_default=$(run_pactl get-default-source 2>/dev/null | tr -d '[:space:]')

        if [ "$prev_default" = "$source_name" ]; then
            echo "Default source already '$source_name'."
            return 0
        fi

        run_pactl set-default-source "$source_name"

        local node_id
        node_id=$(get_source_object_id "$source_name")
        if [ -n "$node_id" ]; then
            run_as_user env XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-default "$node_id"
            echo "Set WirePlumber default to node $node_id ($source_name)."
        else
            echo "WARN: Could not resolve node ID for source '$source_name', wpctl default not set." >&2
        fi

        move_source_outputs_from_to "$prev_default" "$source_name"
    }

    get_card_name() {
        run_pactl list short cards | awk '{print $2}' |
            grep -F "$SOUND_CARD_NAME_PATTERN" | head -n1
    }

    get_active_profile() {
        run_pactl list cards | awk -v pat="$SOUND_CARD_NAME_PATTERN" '
            /^Card #/ { in_card = 0 }
            /^\tName: / { in_card = (index($0, pat) > 0) }
            in_card && /^\tActive Profile:/ {
                sub(/^\tActive Profile: /, "")
                print
                exit
            }
        '
    }

    ensure_profile() {
        local profile="$1"
        local card_name active
        card_name=$(get_card_name)
        if [ -z "$card_name" ]; then
            echo "ERROR: Could not find sound card matching '$SOUND_CARD_NAME_PATTERN'" >&2
            return 1
        fi
        active=$(get_active_profile)
        if [ "$active" = "$profile" ]; then
            echo "Card profile already '$profile'."
            return 0
        fi
        echo "Switching card profile: '$active' -> '$profile'."
        run_pactl set-card-profile "$card_name" "$profile"
    }

    # Print the available HDMI port (e.g. "HDMI1") whose monitor matches
    # $HDMI_MONITOR_NAME, or nothing if none is connected.
    get_target_hdmi_port() {
        run_pactl list cards | awk \
            -v pat="$SOUND_CARD_NAME_PATTERN" \
            -v monitor="$HDMI_MONITOR_NAME" '
            function flush() {
                if (cur_port != "" && avail == 1 && prod != "" \
                    && index(prod, monitor) > 0 && !result) {
                    result = cur_port
                }
                cur_port = ""; prod = ""; avail = 0
            }
            /^Card #/ { in_card = 0; flush() }
            /^\tName: / { in_card = (index($0, pat) > 0) }
            in_card && /^\t\t\[(Out|In)\] / {
                flush()
                if (match($0, /HDMI[0-9]+/)) {
                    cur_port = substr($0, RSTART, RLENGTH)
                    avail = ($0 ~ /, available\)$/) ? 1 : 0
                }
            }
            in_card && cur_port != "" && /device\.product\.name = / {
                if (match($0, /"[^"]*"/)) prod = substr($0, RSTART+1, RLENGTH-2)
            }
            END { flush(); if (result) print result }
        '
    }

    wait_for_sound_card() {
        local max_attempts=15
        local delay=2
        local attempt=1

        while [ $attempt -le $max_attempts ]; do
            if [ -n "$(get_card_name)" ]; then
                return 0
            fi
            echo "Waiting for sound card '$SOUND_CARD_NAME_PATTERN' (attempt $attempt/$max_attempts)..."
            sleep $delay
            ((attempt++))
        done

        echo "ERROR: Sound card '$SOUND_CARD_NAME_PATTERN' not found after ${max_attempts}s" >&2
        return 1
    }

    # Wait for a Bluetooth sink to appear; sets $BT_SINK.
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

    # Pick the default sink: Bluetooth > HDMI ($HDMI_MONITOR_NAME) > speakers.
    update_audio_sink() {
        echo "Updating audio sink based on device priority..."

        if ! wait_for_sound_card; then
            return 1
        fi

        local BT_SINK
        BT_SINK=$(run_pactl list short sinks | grep "bluez_output" | awk '{print $2}' | head -n 1)
        if [ -n "$BT_SINK" ]; then
            echo "Using Bluetooth sink: $BT_SINK."
            set_default_sink "$BT_SINK"
            return
        fi
        echo "No active Bluetooth sink."

        local hdmi_port
        hdmi_port=$(get_target_hdmi_port)
        if [ -n "$hdmi_port" ]; then
            local hdmi_sink="${SINK_PREFIX}.HiFi__${hdmi_port}__sink"
            echo "Using HDMI ($HDMI_MONITOR_NAME on $hdmi_port): $hdmi_sink."
            set_default_sink "$hdmi_sink"
            return
        fi
        echo "No HDMI monitor matching '$HDMI_MONITOR_NAME' is connected."

        echo "Falling back to laptop speakers."
        ensure_profile "$SPEAKER_PROFILE" || return 1
        set_default_sink "$SPEAKER_SINK"
    }

    # First source matching KNOWN_GOOD_MIC_PATTERNS in priority order. Monitor
    # sources are skipped.
    get_preferred_mic_source() {
        local sources
        sources=$(run_pactl list short sources 2>/dev/null |
            awk '$2 !~ /\.monitor$/ {print $2}')
        [ -z "$sources" ] && return 1

        local pattern match
        for pattern in "${KNOWN_GOOD_MIC_PATTERNS[@]}"; do
            match=$(printf '%s\n' "$sources" | grep -F -- "$pattern" | head -n1)
            if [ -n "$match" ]; then
                printf '%s\n' "$match"
                return 0
            fi
        done
        return 1
    }

    # Promote a known-good mic to default if present, else leave the existing
    # default alone (e.g. a user-picked USB headset not in the whitelist).
    update_audio_source() {
        echo "Updating default microphone based on known-good list..."
        if [ ${#KNOWN_GOOD_MIC_PATTERNS[@]} -eq 0 ]; then
            echo "KNOWN_GOOD_MIC_PATTERNS is empty; skipping mic selection."
            return 0
        fi

        local mic
        mic=$(get_preferred_mic_source) || {
            echo "No known-good microphone found among current sources; leaving default as-is."
            return 0
        }
        echo "Using microphone: $mic."
        set_default_source "$mic"
    }

    echo "Script called with:" "$@"

    # On Bluetooth connect, wait for the sink and switch to it; otherwise run
    # the priority check. Mic selection runs after both paths.
    if [[ "$1" == "--device-connect" && "$2" == "bluetooth" ]] && wait_for_bluetooth_sink; then
        echo "Using Bluetooth sink: $BT_SINK."
        set_default_sink "$BT_SINK"
    else
        if [[ "$1" == "--device-connect" && "$2" == "bluetooth" ]]; then
            echo "Bluetooth sink did not appear in time, running normal priority check..."
        fi
        update_audio_sink
    fi

    update_audio_source
}

if [[ -z "$INVOCATION_ID" ]]; then
    CMD=(systemd-run --user --unit smart-audio-switcher -- "$0" "$@")
    if ! sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$USER")" "${CMD[@]}"; then
        # If the user manager isn't ready yet (early boot/login), don't fail udev.
        echo "WARN: systemd-run --user failed; user session may not be ready yet" >&2
    fi
    exit 0
fi

# Prevent concurrent runs racing on multiple udev events.
LOCK_FILE="/tmp/smart-audio-switcher.lock"
exec {lock_fd}>"$LOCK_FILE"
if ! flock -n "$lock_fd"; then
    echo "Another instance is already running. Exiting."
    exit 0
fi

main "$@"
