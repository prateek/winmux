#!/usr/bin/env python3
"""Record close acceptance and each subsequent model readback in the guest."""
import json
from pathlib import Path
import subprocess
import sys
import time

checkout, prefix, raw_id = sys.argv[1:]
window_id = int(raw_id)
cli = Path.home() / checkout / ".build/debug/winmux"
out = Path.home() / "takes/close35" / prefix
out.mkdir(parents=True, exist_ok=True)
start_utc = time.time()
start = time.monotonic()
result = subprocess.run([str(cli), "close", "--window-id", raw_id], text=True, capture_output=True, check=False)
record = {"started_at_epoch": start_utc, "window_id": window_id, "command_ms": (time.monotonic() - start) * 1000,
          "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr, "polls": []}
for index in range(25):
    before = (time.monotonic() - start) * 1000
    windows = subprocess.run([str(cli), "list-windows", "--all", "--format", "%{window-id}|%{app-name}|%{window-title}|%{workspace}"],
                             text=True, capture_output=True, check=True).stdout
    record["polls"].append({"start_ms": before, "end_ms": (time.monotonic() - start) * 1000, "windows": windows,
                            "target": [line for line in windows.splitlines() if line.startswith(raw_id + "|")]})
    if index == 0:
        subprocess.run(["/usr/sbin/screencapture", "-x", str(out / "immediate.png")], check=True)
    time.sleep(0.05)
subprocess.run(["/usr/sbin/screencapture", "-x", str(out / "after.png")], check=True)
(out / "observations.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
