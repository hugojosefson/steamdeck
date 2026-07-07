#!/usr/bin/env python3
"""Add a non-Steam game shortcut to Steam's shortcuts.vdf idempotently."""
import os
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 3:
        print("Usage: add-steam-shortcut.py <name> <exe> [start_dir]")
        return 1

    name = sys.argv[1]
    exe = os.path.abspath(sys.argv[2])
    start_dir = os.path.abspath(sys.argv[3]) if len(sys.argv) > 3 else os.path.dirname(exe)

    userdata = Path.home() / ".local/share/Steam/userdata"
    if not userdata.is_dir():
        print("Steam userdata not found")
        return 1

    try:
        import vdf
    except ImportError:
        print(">>> Installing python-vdf...")
        rc = os.system("pip3 install --user vdf 2>/dev/null")
        if rc != 0:
            os.system("pip3 install vdf 2>/dev/null")
        try:
            import vdf
        except ImportError:
            print("Failed to install vdf. Try: pip3 install vdf")
            return 1

    found = False
    for uid_dir in sorted(userdata.iterdir()):
        shortcuts_file = uid_dir / "config/shortcuts.vdf"
        if not shortcuts_file.is_file():
            continue

        try:
            with open(shortcuts_file, "rb") as f:
                data = vdf.binary_load(f)
        except Exception:
            data = {"shortcuts": {}}

        shortcuts = data.get("shortcuts", {})

        exists = any(
            isinstance(entry, dict) and entry.get("appname") == name
            for entry in shortcuts.values()
        )
        if exists:
            print(f"Shortcut '{name}' already exists for user {uid_dir.name}")
            found = True
            continue

        idx = 0
        while str(idx) in shortcuts:
            idx += 1

        shortcuts[str(idx)] = {
            "appname": name,
            "exe": f'"{exe}"',
            "StartDir": start_dir,
            "icon": "",
            "ShortcutPath": "",
            "IsHidden": 0,
            "AllowDesktopConfig": 1,
            "AllowOverlay": 1,
            "OpenVR": 0,
            "Devkit": 0,
            "DevkitGameID": "",
            "LastPlaytime": 0,
            "FlatpakAppId": "",
            "tags": {},
        }

        with open(shortcuts_file, "wb") as f:
            vdf.binary_dump(f, {"shortcuts": shortcuts})

        print(f"Added Steam shortcut '{name}' for user {uid_dir.name}")
        found = True

    if not found:
        print("No Steam user config found. Install the script manually:\n"
              "  Steam → Library → Add a Non-Steam Game → Browse → select exodos-browser.sh")
        return 1

    print("Restart Steam or switch to Gaming Mode to see the new shortcut.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
