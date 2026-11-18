#!/usr/bin/env python3
"""Seed writable DMS plugin preferences without overwriting GUI choices."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def read_json(path):
    return json.loads(path.read_text()) if path.exists() and path.stat().st_size > 0 else {}


def write_json(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    root = Path(sys.argv[1]) / "DankMaterialShell"
    specs = json.loads(Path(sys.argv[2]).read_text())
    plugins_path = root / "plugin_settings.json"
    plugins = read_json(plugins_path)
    new_widgets = []
    live_enable_ids = []
    changed = False

    for plugin_id, spec in specs.items():
        if not (root / "plugins" / plugin_id).is_dir():
            continue
        entry = plugins.setdefault(plugin_id, {})
        if "enabled" not in entry:
            default_enabled = spec.get("defaultEnabled", True)
            entry["enabled"] = default_enabled
            changed = True
            if default_enabled:
                if spec.get("barWidget", False):
                    new_widgets.append((spec.get("barWidgetOrder", 100), plugin_id))
                if spec.get("liveEnableViaIpc", False):
                    live_enable_ids.append(plugin_id)
        for key, value in spec.get("defaultSettings", {}).items():
            if key not in entry:
                entry[key] = value
                changed = True

    new_widgets.sort()
    settings_path = root / "settings.json"
    settings = read_json(settings_path)
    bars = settings.get("barConfigs", [])
    primary = next((bar for bar in bars if bar.get("enabled", True)), None)
    layout_changed = False
    if primary and new_widgets:
        existing = {
            widget if isinstance(widget, str) else widget.get("id", widget.get("widgetId"))
            for section in ("leftWidgets", "centerWidgets", "rightWidgets")
            for widget in primary.get(section, [])
        }
        widgets = primary.setdefault("rightWidgets", [])
        for _, plugin_id in new_widgets:
            if plugin_id not in existing:
                widgets.insert(0, {"id": plugin_id, "enabled": True})
                layout_changed = True
        write_json(settings_path, settings)
    if changed:
        write_json(plugins_path, plugins)

    # DMS can retain the previous layout after an external settings write.
    # Restart an existing user service only when first adding bar widgets.
    restarted = False
    if layout_changed and shutil.which("systemctl"):
        subprocess.run(
            ["systemctl", "--user", "try-restart", "dms.service"],
            check=False,
            timeout=20,
        )
        restarted = True

    if not restarted and live_enable_ids and shutil.which("dms"):
        subprocess.run(
            ["timeout", "5", "dms", "ipc", "call", "plugin-scan", "scan"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        for plugin_id in live_enable_ids:
            subprocess.run(
                ["timeout", "5", "dms", "ipc", "call", "plugins", "enable", plugin_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )


if __name__ == "__main__":
    main()
