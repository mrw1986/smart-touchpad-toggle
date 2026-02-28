#!/usr/bin/env bash
#
# smart-touchpad-monitor.sh — Watch for input device changes and toggle touchpad
#
# Long-running service script that:
# 1. Runs the toggle check once at startup
# 2. Monitors udev input subsystem events
# 3. Re-runs the toggle check on each add/remove event
#
# Debounces rapid events (e.g., Bluetooth mouse emits multiple events).

set -euo pipefail

TOGGLE_SCRIPT="/usr/local/bin/smart-touchpad-toggle.sh"
DEBOUNCE_SECONDS=2

run_toggle() {
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') --- Running touchpad toggle check ---"
    "$TOGGLE_SCRIPT" || echo "WARNING: Toggle script exited with error $?"
}

# Initial check at startup
run_toggle

last_run=0

# Monitor input device changes
stdbuf -oL udevadm monitor --subsystem-match=input --udev 2>&1 | while IFS= read -r line; do
    # Only trigger on add/remove events (not change/bind/unbind)
    if echo "$line" | grep -qE '\b(add|remove)\b'; then
        now=$(date +%s)
        if (( now - last_run >= DEBOUNCE_SECONDS )); then
            last_run=$now
            # Small delay to let the device fully register
            sleep 1
            run_toggle
        fi
    fi
done
