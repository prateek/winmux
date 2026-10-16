#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path(sys.argv[1]).expanduser()
label = sys.argv[2]
out = Path.home() / "takes" / label
out.mkdir(parents=True, exist_ok=True)
cli = root / ".build/debug/winmux"
tools = Path.home() / "arrive-proof"

def command(*args):
    result = subprocess.run([str(cli), *args], text=True, capture_output=True, timeout=20)
    if result.returncode:
        raise RuntimeError(f"{args}: {result.returncode}: {result.stderr}")
    return result.stdout

def inventory():
    return json.loads(command("list-windows", "--all", "--json", "--format",
                              "%{window-id}%{window-title}%{workspace}%{window-layout}"))

def wait_for(predicate):
    until = time.monotonic() + 15
    while time.monotonic() < until:
        value = predicate()
        if value:
            return value
        time.sleep(.1)
    raise RuntimeError("Timed out waiting for window inventory")

Path("/tmp/stage/command").write_text("raise Source anchor")
time.sleep(.3)
if not any(row["window-title"] == "Route anchor" for row in inventory()):
    Path("/tmp/stage/command").write_text("open Route anchor")
route_anchor = wait_for(lambda: next((row for row in inventory() if row["window-title"] == "Route anchor"), None))
command("workspace", "Route")
command("workspace", "Source")
results = []
for trial in range(1, 11):
    title = f"Trial {trial:02d}"
    command("workspace", "Source")
    command("column-count", "3", "--workspace", "Route")
    recorder = None
    if trial == 1:
        recorder = subprocess.Popen([str(tools / "snapshot-recorder"), str(out / "trial.mov"), "7"],
                                    stdout=open(out / "recorder.log", "w"), stderr=subprocess.STDOUT)
        time.sleep(.7)
    key_args = [str(tools / "keys"), str(time.time()), str(out / f"keys-{trial:02d}.json"),
                "delay:0.05", "down:alt"] + ["tap:h"] * 30 + ["up:alt"]
    keys = subprocess.Popen(key_args, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    Path("/tmp/stage/command").write_text("open " + title)
    keys.wait(timeout=15)
    if keys.returncode:
        raise RuntimeError(keys.stderr.read().decode())
    time.sleep(.3)
    command("doctor")
    time.sleep(.3)
    rows = wait_for(lambda: [row for row in inventory() if row["window-title"] == title])
    columns = json.loads(command("list-columns", "--workspace", "Route", "--json"))
    (out / f"windows-{trial:02d}.json").write_text(json.dumps(inventory(), indent=2))
    (out / f"columns-{trial:02d}.json").write_text(json.dumps(columns, indent=2))
    row = rows[0]
    routed = row["workspace"] == "Route"
    ran = len(columns) == 4
    in_column = any(row["window-id"] in col["window-ids"] and col["index"] == 3 for col in columns)
    result = dict(trial=trial, **row, routed=routed, ran=ran, column3=in_column)
    results.append(result)
    print(json.dumps(result), flush=True)
    command("workspace", "Route" if routed else "Source")
    time.sleep(.4)
    subprocess.run(["screencapture", "-x", str(out / f"trial-{trial:02d}-end.png")], check=True)
    if trial == 1:
        recorder.wait(timeout=15)
        if recorder.returncode:
            raise RuntimeError("Recorder failed")
    command("close", "--window-id", str(row["window-id"]))
    wait_for(lambda: not any(row["window-title"] == title for row in inventory()))
(out / "results.json").write_text(json.dumps(results, indent=2))
(out / "status.txt").write_text(command("config", "status"))
print(f"{label}: {sum(r['routed'] for r in results)}/10 routed; {sum(r['ran'] for r in results)}/10 run lists")

Path("/tmp/stage/command").write_text("open Control")
row = wait_for(lambda: next((row for row in inventory() if row["window-title"] == "Control"), None))
window_id = str(row["window-id"])
command("layout", "floating", "--window-id", window_id)
floating = next(row for row in inventory() if row["window-id"] == int(window_id))
command("move-node-to-workspace", "Source", "--window-id", window_id)
moved = next(row for row in inventory() if row["window-id"] == int(window_id))
command("layout", "tiling", "--window-id", window_id)
tiled = next(row for row in inventory() if row["window-id"] == int(window_id))
control = dict(floated=floating["window-layout"] == "floating",
               moved=moved["workspace"] == "Source",
               retiled=tiled["window-layout"] != "floating")
(out / "unchanged.json").write_text(json.dumps(control, indent=2))
assert all(control.values()), control
command("workspace", "Source")
time.sleep(.4)
subprocess.run(["screencapture", "-x", str(out / "unchanged.png")], check=True)
command("close", "--window-id", window_id)

command("close", "--window-id", str(route_anchor["window-id"]))
