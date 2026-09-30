#!/usr/bin/env python3
"""Waybar module: what a computer-use agent is doing in niri.

Reads AgentInputActivity from the niri event stream (niri-computer-use agent
input patch) and prints one Waybar JSON line per update. Hidden while idle.
"""
import json
import os
import select
import socket
import sys
import time

# Same timeout as niri's is-agent-driven window rule.
IDLE_AFTER = 30.0
# Highlighted this long after the last activity.
ACTIVE_FOR = 3.0

KINDS = {
    "Pointer": "移动",
    "Click": "点击",
    "Scroll": "滚动",
    "Keyboard": "输入",
    "Screenshot": "查看",
}

windows = {}  # id -> window
last = None  # (window_id, kind, monotonic time)
shown = None


def emit(output):
    global shown
    if output != shown:
        shown = output
        print(json.dumps(output, ensure_ascii=False), flush=True)


def render():
    if last is None:
        return emit({"text": "", "class": "idle"})
    window_id, kind, at = last
    age = time.monotonic() - at
    if age >= IDLE_AFTER:
        return emit({"text": "", "class": "idle"})

    window = windows.get(window_id, {})
    app_id = window.get("app_id") or "?"
    app = app_id.rsplit(".", 1)[-1]
    title = window.get("title") or ""
    action = KINDS.get(kind, kind)
    state = "active" if age < ACTIVE_FOR else "recent"
    emit({
        "text": f"󰚩 {app} · {action}",
        "tooltip": f"agent → {title or app_id}\n窗口 {window_id} · {action}",
        "class": state,
    })


def handle(event):
    global last
    (name, body), = event.items()
    if name == "WindowsChanged":
        windows.clear()
        windows.update({w["id"]: w for w in body["windows"]})
    elif name == "WindowOpenedOrChanged":
        windows[body["window"]["id"]] = body["window"]
    elif name == "WindowClosed":
        windows.pop(body["id"], None)
        if last and last[0] == body["id"]:
            last = None
    elif name == "AgentInputActivity":
        last = (body["window_id"], body["kind"], time.monotonic())


def stream():
    path = os.environ.get("NIRI_SOCKET")
    if not path:
        raise OSError("NIRI_SOCKET is not set")
    sock = socket.socket(socket.AF_UNIX)
    sock.connect(path)
    sock.sendall(b'"EventStream"\n')
    buf = b""
    replied = False
    while True:
        # Wake up every second to fade and hide the module.
        ready, _, _ = select.select([sock], [], [], 1.0)
        if ready:
            data = sock.recv(65536)
            if not data:
                raise OSError("niri closed the event stream")
            buf += data
            *lines, buf = buf.split(b"\n")
            for line in lines:
                if not replied:
                    replied = True  # {"Ok":"Handled"}
                    continue
                handle(json.loads(line))
        render()


def main():
    global last
    while True:
        try:
            stream()
        except (OSError, ValueError) as err:
            print(f"agent-activity: {err}", file=sys.stderr)
        windows.clear()
        last = None
        render()
        time.sleep(2)


if __name__ == "__main__":
    main()
