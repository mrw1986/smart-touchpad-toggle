# Smart Touchpad Toggle for KDE Plasma Wayland

Automatically disables the laptop touchpad when a real external mouse (e.g., Bluetooth) is connected, and re-enables it when the mouse disconnects.

## Why?

KDE Plasma has a built-in "Disable touchpad when external mouse is connected" option (`DisableEventsOnExternalMouse`), but it doesn't work when you use tools like **keyd**, **dotool**, or **ydotoold** — their virtual pointer devices are counted as "external mice," permanently disabling the touchpad.

This project provides a custom solution that:

- Filters out virtual pointer devices (keyd, dotool, ydotoold)
- Filters out the touchpad's companion Mouse device (same vendor:product ID)
- Only counts **real** external mice (e.g., Logitech M650 L over Bluetooth)
- Responds to device connect/disconnect within ~2 seconds

## How It Works

1. A **systemd user service** runs a monitor script that watches for input device changes via `udevadm monitor`
2. On any input device add/remove event, it runs the **toggle script**
3. The toggle script parses `/proc/bus/input/devices` to find all mouse devices, filters out virtual ones, and enables/disables the touchpad via KWin's DBus interface

## Requirements

- KDE Plasma 6 on Wayland
- `dbus-send` (usually pre-installed)
- `udevadm` (usually pre-installed)
- `stdbuf` from coreutils (usually pre-installed)

## Installation

```bash
git clone https://github.com/mrw1986/smart-touchpad-toggle.git
cd smart-touchpad-toggle
./install.sh
```

This will:
- Copy scripts to `/usr/local/bin/`
- Install the systemd user service
- Enable and start the service

## Uninstallation

```bash
./uninstall.sh
```

This will stop the service, remove all installed files, and re-enable the touchpad.

## Manual Usage

Run the toggle script directly:

```bash
smart-touchpad-toggle.sh
```

Check service status:

```bash
systemctl --user status smart-touchpad-monitor.service
```

Follow logs:

```bash
journalctl --user -u smart-touchpad-monitor.service -f
```

## Files

| File | Purpose |
|------|---------|
| `smart-touchpad-toggle.sh` | Main logic — detects mice, toggles touchpad via DBus |
| `smart-touchpad-monitor.sh` | Monitor wrapper — watches udev events, calls toggle script |
| `smart-touchpad-monitor.service` | Systemd user service unit |
| `install.sh` | Installer script |
| `uninstall.sh` | Uninstaller script |

## Configuration

The virtual device filter is defined at the top of `smart-touchpad-toggle.sh`:

```bash
VIRTUAL_PATTERNS="keyd|dotool|ydotoold"
```

Add any additional virtual device name patterns as needed (case-insensitive match against device names in `/proc/bus/input/devices`).

## Tested On

- ASUS laptop with `ASCP1201:00 093A:3017` I2C touchpad
- Logitech Signature M650 L (Bluetooth)
- Fedora 43, KDE Plasma 6, Wayland
- Virtual pointers: keyd, dotool, ydotoold

## License

MIT
