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
    return json.loads(path.read_text()) if path.exists() else {}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    root = Path(sys.argv[1]) / "DankMaterialShell"
    plugins_path = root / "plugin_settings.json"
    plugins = read_json(plugins_path)
    ids = ("calculator", "dankTranslate", "dankscale", "dankPomodoroTimer")
    new_widgets = []
    changed = False
    for plugin_id in ids:
        entry = plugins.setdefault(plugin_id, {})
        if "enabled" not in entry:
            entry["enabled"] = True
            changed = True
            if plugin_id in ("dankscale", "dankPomodoroTimer"):
                new_widgets.append(plugin_id)
    translation = plugins["dankTranslate"]
    if "defaultLang" not in translation:
        translation["defaultLang"] = "zh-CN"
        changed = True

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
        for plugin_id in new_widgets:
            if plugin_id not in existing:
                widgets.insert(0, {"id": plugin_id, "enabled": True})
                layout_changed = True
        write_json(settings_path, settings)
    if changed:
        write_json(plugins_path, plugins)
    # DMS can retain the previous layout after an external settings write.
    # Restart an existing user service only when first adding bar widgets.
    if layout_changed and shutil.which("systemctl"):
        subprocess.run(
            ["systemctl", "--user", "try-restart", "dms.service"],
            check=False,
            timeout=20,
        )


if __name__ == "__main__":
    main()
