#!/usr/bin/env bash
#
# install.sh — Install smart-touchpad-toggle scripts and service
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing scripts to /usr/local/bin/..."
sudo install -m 755 "$SCRIPT_DIR/smart-touchpad-toggle.sh" /usr/local/bin/
sudo install -m 755 "$SCRIPT_DIR/smart-touchpad-monitor.sh" /usr/local/bin/

echo "Installing systemd user service..."
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$SCRIPT_DIR/smart-touchpad-monitor.service" "$HOME/.config/systemd/user/"

echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "Enabling and starting service..."
systemctl --user enable --now smart-touchpad-monitor.service

echo ""
echo "Done! Check status with:"
echo "  systemctl --user status smart-touchpad-monitor.service"
echo "  journalctl --user -u smart-touchpad-monitor.service -f"
