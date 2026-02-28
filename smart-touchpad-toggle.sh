#!/usr/bin/env bash
#
# smart-touchpad-toggle.sh — Toggle touchpad based on real external mice
#
# KDE's DisableEventsOnExternalMouse counts virtual pointers (keyd, dotool,
# ydotoold) as external mice, permanently disabling the touchpad. This script
# only counts real external mice and ignores virtual pointers.
#
# Usage: Called by smart-touchpad-monitor.service on input device changes.
#        Requires DBUS_SESSION_BUS_ADDRESS to be set.

set -euo pipefail

# Virtual device name patterns to ignore (case-insensitive grep)
VIRTUAL_PATTERNS="keyd|dotool|ydotoold"

find_touchpad_event() {
    # Find the touchpad's eventN from /proc/bus/input/devices
    local in_touchpad_block=false
    while IFS= read -r line; do
        if [[ "$line" == N:* && "$line" == *Touchpad* ]]; then
            in_touchpad_block=true
        elif [[ "$line" == N:* ]]; then
            in_touchpad_block=false
        elif $in_touchpad_block && [[ "$line" == H:* ]]; then
            # Extract eventN from handlers line
            if [[ "$line" =~ event([0-9]+) ]]; then
                echo "event${BASH_REMATCH[1]}"
                return 0
            fi
        fi
    done < /proc/bus/input/devices
    return 1
}

find_touchpad_vendor_product() {
    # Get the vendor:product ID of the touchpad to filter its companion Mouse device
    # Note: I: line comes BEFORE N: line in each block, so we must collect both
    # and evaluate at the end of each block (blank line)
    local name="" vendor_product=""
    while IFS= read -r line; do
        case "$line" in
            I:*)
                vendor_product=""
                if [[ "$line" =~ Vendor=([0-9a-fA-F]+).*Product=([0-9a-fA-F]+) ]]; then
                    vendor_product="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
                fi
                ;;
            N:*)
                name="$line"
                ;;
            "")
                if [[ "$name" == *Touchpad* && -n "$vendor_product" ]]; then
                    echo "$vendor_product"
                    return 0
                fi
                name=""
                vendor_product=""
                ;;
        esac
    done < /proc/bus/input/devices
    return 1
}

has_real_external_mouse() {
    local touchpad_vp="$1"

    # Parse /proc/bus/input/devices block by block
    local name="" vendor_product="" handlers="" is_virtual=false
    while IFS= read -r line; do
        case "$line" in
            N:*)
                name="$line"
                is_virtual=false
                if echo "$name" | grep -qiE "$VIRTUAL_PATTERNS"; then
                    is_virtual=true
                fi
                ;;
            I:*)
                vendor_product=""
                if [[ "$line" =~ Vendor=([0-9a-fA-F]+).*Product=([0-9a-fA-F]+) ]]; then
                    vendor_product="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
                fi
                ;;
            H:*)
                handlers="$line"
                ;;
            "")
                # End of a device block — evaluate it
                if [[ -n "$handlers" ]] && echo "$handlers" | grep -q "mouse"; then
                    # It's a mouse/pointer device
                    if ! $is_virtual \
                        && [[ "$name" != *Touchpad* ]] \
                        && [[ "$vendor_product" != "$touchpad_vp" ]]; then
                        # Real external mouse found
                        local clean_name
                        clean_name=$(echo "$name" | sed 's/^N: Name="//;s/"$//')
                        echo "$clean_name"
                        return 0
                    fi
                fi
                # Reset for next block
                name=""
                vendor_product=""
                handlers=""
                is_virtual=false
                ;;
        esac
    done < /proc/bus/input/devices
    return 1
}

set_touchpad_enabled() {
    local event_device="$1"
    local enabled="$2"  # "true" or "false"

    dbus-send --session \
        --dest=org.kde.KWin \
        --type=method_call \
        "/org/kde/KWin/InputDevice/${event_device}" \
        org.freedesktop.DBus.Properties.Set \
        string:org.kde.KWin.InputDevice \
        string:enabled \
        variant:boolean:"$enabled"
}

get_touchpad_enabled() {
    local event_device="$1"
    dbus-send --session --print-reply \
        --dest=org.kde.KWin \
        "/org/kde/KWin/InputDevice/${event_device}" \
        org.freedesktop.DBus.Properties.Get \
        string:org.kde.KWin.InputDevice \
        string:enabled 2>/dev/null | grep -oP 'boolean \K\w+'
}

main() {
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        echo "ERROR: DBUS_SESSION_BUS_ADDRESS not set" >&2
        exit 1
    fi

    local touchpad_event
    touchpad_event=$(find_touchpad_event) || {
        echo "ERROR: No touchpad found in /proc/bus/input/devices" >&2
        exit 1
    }
    echo "Touchpad device: $touchpad_event"

    local touchpad_vp
    touchpad_vp=$(find_touchpad_vendor_product) || touchpad_vp=""
    echo "Touchpad vendor:product: ${touchpad_vp:-unknown}"

    local mouse_name
    if mouse_name=$(has_real_external_mouse "$touchpad_vp"); then
        echo "Real external mouse detected: $mouse_name"
        local current
        current=$(get_touchpad_enabled "$touchpad_event")
        if [[ "$current" == "true" ]]; then
            echo "Disabling touchpad"
            set_touchpad_enabled "$touchpad_event" false
        else
            echo "Touchpad already disabled"
        fi
    else
        echo "No real external mouse detected"
        local current
        current=$(get_touchpad_enabled "$touchpad_event")
        if [[ "$current" == "false" ]]; then
            echo "Enabling touchpad"
            set_touchpad_enabled "$touchpad_event" true
        else
            echo "Touchpad already enabled"
        fi
    fi
}

main "$@"
