#!/usr/bin/env python3
"""Run unchanged against a base or feature build inside the owned guest."""
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path(sys.argv[1]).expanduser()
label = sys.argv[2]
expected_width = float(sys.argv[3])
expected_loop = sys.argv[4]
out = Path.home() / "takes" / label
out.mkdir(parents=True, exist_ok=True)
cli = root / ".build/debug/winmux"
transcript = []

def command(*args):
    result = subprocess.run([str(cli), *args], text=True, capture_output=True, timeout=20)
    transcript.append("$ winmux " + " ".join(args) + "\n" + result.stdout + result.stderr)
    (out / "transcript.txt").write_text("\n".join(transcript))
    if result.returncode:
        raise RuntimeError(f"{args}: {result.returncode}: {result.stderr}")
    return result.stdout

def inventory():
    return json.loads(command("list-windows", "--all", "--json", "--format",
                              "%{window-id}%{window-title}%{workspace}%{window-layout}"))

def stage(action):
    Path("/tmp/stage/command").write_text(action)
    time.sleep(.5)

def window(title):
    # Let detection run without read-only polling, which can starve its refresh.
    time.sleep(1)
    command("doctor")
    rows = inventory()
    return next(row for row in rows if row["window-title"] == title)

def capture(name):
    time.sleep(.5)
    subprocess.run(["screencapture", "-x", str(out / (name + ".png"))], check=True)

results = []
for trial in range(1, 4):
    command("workspace", "Source")
    command("balance-sizes", "--workspace", "3")
    stage("raise Source anchor")
    stage("open Chain")
    row = window("Chain")
    columns = json.loads(command("list-columns", "--workspace", "3", "--json"))
    status = command("config", "status")
    result = dict(trial=trial, window=row, columns=columns, status=status)
    results.append(result)
    (out / "chain.json").write_text(json.dumps(results, indent=2))
    assert row["workspace"] == "3", result
    assert row["window-id"] in columns[1]["window-ids"], result
    assert abs(columns[1]["width"] - expected_width) < .000001, result
    command("workspace", "3")
    capture(f"chain-{trial}")
    command("close", "--window-id", str(row["window-id"]))

command("workspace", "Source")
stage("open Loop")
row = window("Loop")
id_arg = str(row["window-id"])
# The dry-run preview must leave the complete inventory and widths intact.
command("workspace", "Ping")
before_windows = inventory()
before_columns = command("list-columns", "--workspace", "Ping", "--json")
preview = command("place", "--dry-run", "--window-id", id_arg, "--json")
assert inventory() == before_windows
assert command("list-columns", "--workspace", "Ping", "--json") == before_columns
command("move-node-to-workspace", "Ping", "--window-id", id_arg)
row = next(row for row in inventory() if row["window-id"] == int(id_arg))
columns = json.loads(command("list-columns", "--workspace", expected_loop, "--json"))
status = command("config", "status")
loop = dict(window=row, columns=columns, status=status, preview=preview)
(out / "loop.json").write_text(json.dumps(loop, indent=2))
assert row["workspace"] == expected_loop, loop
slot = 2 if expected_loop == "Ping" else 3
assert row["window-id"] in columns[slot - 1]["window-ids"], loop
message = ("Policy run: workspace.Ping.columns.place is already running for this window; its run list is suppressed"
           if expected_loop == "Ping" else "Policy run: nested run list suppressed")
assert message in status, loop
command("workspace", expected_loop)
capture("loop")
# Preserved floating-to-tiling and transfer behavior, same commands on both trees.
command("layout", "floating", "--window-id", id_arg)
command("move-node-to-workspace", "Source", "--window-id", id_arg)
command("layout", "tiling", "--window-id", id_arg)
row = next(row for row in inventory() if row["window-id"] == int(id_arg))
assert row["workspace"] == "Source" and row["window-layout"] != "floating", row
(out / "unchanged.json").write_text(json.dumps(row, indent=2))
capture("unchanged")
command("close", "--window-id", id_arg)
print(f"{label}: 3/3 chains at {expected_width}; loop on {expected_loop}; dry run and restoration passed")
