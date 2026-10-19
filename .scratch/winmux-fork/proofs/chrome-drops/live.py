"""Guest-only staging, held pointer captures, and fixed-delay native readbacks."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HOME = Path.home()
OUT = HOME / "takes/chrome-drops"
CLI = Path(os.environ.get("WINMUX_CLI", HOME / "winmux/.build/debug/winmux"))
CLICK = "/opt/homebrew/bin/cliclick"
OUT.mkdir(parents=True, exist_ok=True)


def run(*args):
    return subprocess.run(list(map(str, args)), check=True, capture_output=True, text=True).stdout


def cli(*args):
    return run(CLI, *args)


def capture(name):
    run("screencapture", "-x", OUT / (name + ".png"))
    pid = run("pgrep", "-x", "WinMuxApp").strip()
    (OUT / (name + ".ui.json")).write_text(run(HOME / "demo/ui", pid))


def snapshot(name):
    time.sleep(6)
    (OUT / (name + ".windows.txt")).write_text(cli("list-windows", "--all", "--format", "%{window-id}|%{window-title}|%{workspace}|%{window-layout}"))
    tree = json.loads(cli("agent", "query"))
    (OUT / (name + ".tree.json")).write_text(json.dumps(tree, indent=2))
    capture(name)
    return tree


def stage(name):
    tree = json.loads(cli("agent", "query"))
    ids = {w["title"]: w["windowId"] for w in tree["inventory"]["windows"]}
    groups = [["Red", "Blue", "Green"], ["Yellow", "Violet", "Orange"], ["Teal", "Pink", "Grey"], ["White", "Brown", "Black"], ["Amber", "Cyan", "Rose"]]
    for index, titles in enumerate(groups, 1):
        for title in titles:
            cli("move-node-to-workspace", "--window-id", ids[title], str(index))
    cli("workspace", "1")
    cli("focus", "--window-id", ids["Red"])
    run(CLICK, "m:160,300", "w:1000")
    snapshot(name + "-staged")


def drag(name, sx, sy, tx, ty):
    capture(name + "-before")
    commands = [f"m:{sx},{sy}", "w:1000", f"dd:{sx},{sy}", "w:250", f"dm:{sx+12},{sy+5}", "w:400", f"dm:{tx},{ty}", "w:3000", f"du:{tx},{ty}", "w:800"]
    (OUT / (name + ".input.json")).write_text(json.dumps(commands))
    pointer = subprocess.Popen([CLICK, *commands], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(3.2)
    capture(name + "-preview")
    stdout, stderr = pointer.communicate(timeout=20)
    if pointer.returncode:
        raise RuntimeError((stdout, stderr))
    snapshot(name + "-after")


if __name__ == "__main__":
    mode, name, *args = sys.argv[1:]
    if mode == "stage":
        stage(name)
    elif mode == "snapshot":
        snapshot(name)
    elif mode == "drag":
        drag(name, *map(int, args))
    elif mode == "scroll":
        run(CLICK, "m:160,400", "w:400")
        run(HOME / "demo/scroll", args[0])
        time.sleep(2)
        snapshot(name)
    else:
        raise SystemExit("stage NAME; snapshot NAME; drag NAME SX SY TX TY; scroll NAME AMOUNT")
