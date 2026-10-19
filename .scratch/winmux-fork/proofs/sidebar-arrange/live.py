#!/usr/bin/env python3
"""Guest pointer checks with screen, AX and native layout evidence."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HOME = Path.home()
OUT = HOME / "takes/sidebar-arrange"
CLI = Path(os.environ.get("WINMUX_CLI", HOME / "winmux/.build/debug/winmux"))
CLICK = "/opt/homebrew/bin/cliclick"
UI = HOME / "sidebar-tree-proof/ui"
BUTTONS = HOME / "sidebar-arrange-proof/buttons"


def run(*args):
    return subprocess.run(list(map(str, args)), check=True, capture_output=True, text=True).stdout


def rows():
    return json.loads(run(UI, run("pgrep", "-x", "WinMuxApp").strip()))


def find(label, occurrence=0, role="AXButton"):
    def matches_label(row):
        if label.startswith("@tabs:"):
            return row["description"].endswith(", " + label.split(":")[1])
        return label in (row["title"], row["description"], row["value"])
    matches = [row for row in rows() if row["role"] == role and
               matches_label(row) and row["x"] < 340 and
               0 < row["height"] < 40 and row["y"] > 0]
    if len(matches) <= occurrence:
        raise RuntimeError((label, occurrence, matches))
    return matches[occurrence]


def center(row):
    return round(row["x"] + row["width"] / 2), round(row["y"] + row["height"] / 2)


def capture(name):
    run("screencapture", "-x", OUT / (name + ".png"))
    (OUT / (name + ".ui.json")).write_text(json.dumps(rows(), indent=2))


def readback(name):
    time.sleep(5)
    (OUT / (name + ".windows.txt")).write_text(run(CLI, "list-windows", "--all", "--format",
        "%{window-id}|%{app-name}|%{window-title}|%{workspace}|%{window-layout}"))
    (OUT / (name + ".tree.json")).write_text(run(CLI, "agent", "query"))
    (OUT / (name + ".columns.json")).write_text(run(CLI, "list-columns", "--workspace", "2", "--json"))


def drag(name, source, target, intent, source_index=0, target_index=0, release_option=False):
    before_buttons = json.loads(run(BUTTONS))
    if before_buttons["leftDown"]:
        raise RuntimeError("The input driver left the mouse button down before this take")
    sx, sy = center(find(source, source_index))
    row = find(target, target_index)
    tx, ty = center(row)
    option = intent not in ("before", "after")
    if option:
        index = ["tab", "left", "right", "top", "bottom", "middle"].index(intent)
        tx = round(row["x"] + row["width"] * (index + 0.5) / 6)
    else:
        ty += round(row["height"] * (-0.3 if intent == "before" else 0.3))
    capture(name + "-before")
    commands = (["kd:alt"] if option else []) + [f"dd:{sx},{sy}", "w:200",
        f"dm:{sx + 8},{sy + 3}", "w:200", f"dm:{tx},{ty}", "w:5000"]
    if release_option:
        commands += ["ku:alt", "w:5000"]
    commands += [f"du:{tx},{ty}"]
    if option and not release_option:
        commands += ["ku:alt"]
    commands += ["w:500"]
    (OUT / (name + ".input.json")).write_text(json.dumps(commands))
    process = subprocess.Popen([CLICK, *commands], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(3)
    capture(name + "-preview")
    if release_option:
        time.sleep(5)
        capture(name + "-released-preview")
    stdout, stderr = process.communicate(timeout=20)
    if process.returncode:
        raise RuntimeError((stdout, stderr))
    after_buttons = json.loads(run(BUTTONS))
    (OUT / (name + ".buttons.json")).write_text(json.dumps({"before": before_buttons, "after": after_buttons}))
    if after_buttons["leftDown"]:
        capture(name + "-input-not-released")
        raise RuntimeError("The input driver did not release the mouse button")
    time.sleep(3)
    capture(name + "-after")
    readback(name)


OUT.mkdir(parents=True, exist_ok=True)
mode, name, *args = sys.argv[1:]
if mode == "snapshot":
    capture(name)
    readback(name)
elif mode in ("drag", "release"):
    source, target, intent, *indices = args
    drag(name, source, target, intent, *map(int, indices), release_option=mode == "release")
elif mode in ("click", "rightclick"):
    label, *indices = args
    x, y = center(find(label, int(indices[0]) if indices else 0))
    run(CLICK, f"{'rc' if mode == 'rightclick' else 'c'}:{x},{y}", "w:1000")
    capture(name)
    if mode == "click":
        readback(name)
elif mode == "menu":
    label, action, *indices = args
    x, y = center(find(label, int(indices[0]) if indices else 0))
    run(CLICK, f"rc:{x},{y}", "w:700")
    capture(name + "-menu")
    item = find(action, role="AXMenuItem")
    x, y = center(item)
    run(CLICK, f"c:{x},{y}", "w:1000")
    time.sleep(3)
    capture(name + "-after")
    readback(name)
else:
    raise SystemExit("snapshot, drag, click, rightclick or menu")
