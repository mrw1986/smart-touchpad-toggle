#!/usr/bin/env bash
#
# uninstall.sh — Remove smart-touchpad-toggle scripts and service
#
set -euo pipefail

echo "Stopping and disabling service..."
systemctl --user disable --now smart-touchpad-monitor.service 2>/dev/null || true

echo "Removing systemd user service..."
rm -f "$HOME/.config/systemd/user/smart-touchpad-monitor.service"
systemctl --user daemon-reload

echo "Removing scripts from /usr/local/bin/..."
sudo rm -f /usr/local/bin/smart-touchpad-toggle.sh
sudo rm -f /usr/local/bin/smart-touchpad-monitor.sh

echo "Re-enabling touchpad..."
# Try to re-enable the touchpad in case it was left disabled
for i in $(seq 0 30); do
    name=$(dbus-send --session --print-reply --dest=org.kde.KWin \
        "/org/kde/KWin/InputDevice/event$i" \
        org.freedesktop.DBus.Properties.Get \
        string:org.kde.KWin.InputDevice string:name 2>/dev/null \
        | grep -oP 'string "\K[^"]+' || true)
    if [[ "$name" == *Touchpad* ]]; then
        dbus-send --session --dest=org.kde.KWin --type=method_call \
            "/org/kde/KWin/InputDevice/event$i" \
            org.freedesktop.DBus.Properties.Set \
            string:org.kde.KWin.InputDevice string:enabled \
            variant:boolean:true 2>/dev/null || true
        echo "Touchpad (event$i) re-enabled."
        break
    fi
done

echo "Done!"
