"""Check the captured readbacks, independent of the desktop-driving script."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])


def text(name):
    return (root / name).read_text()


def trace(name):
    return json.loads(text(name))[0]


assert text("workspace-cli.txt") == text("workspace-url.txt") == "2\n"
assert text("mode-cli.txt") == text("mode-url.txt") == "window\n"
assert text("mode-return.txt") == "main\n"
cli, url = trace("overview-cli.json"), trace("overview-url.json")
assert cli["source"] == "CLI" and url["source"] == "URL"
assert cli["presentation"] == url["presentation"] == "miniatures"
for key in ["active", "hold", "search", "selectedId", "state", "presentation"]:
    assert cli["session"][key] == url["session"][key], key
assert cli["session"]["active"] is True
assert trace("overview-cli-closed.json")["session"]["active"] is False
assert trace("overview-url-closed.json")["session"]["active"] is False
for index in range(1, 8):
    assert text(f"refusal-{index}-windows.txt") == text("refusals-before-windows.txt")
    assert text(f"refusal-{index}-workspace.txt") == text("refusals-before-workspace.txt")
assert text("setting-off-workspace.txt") == text("refusals-before-workspace.txt")
assert text("ordered-workspace.txt") == "1\n"
assert text("socket-base.jsonl") == text("socket-head.jsonl")
assert len(text("socket-base.jsonl").splitlines()) == 11
log = text("url.log")
for reason in ["Empty argument segment", "Expected run host", "reads stdin or prints a result",
               "exec-and-forget is prohibited in CLI", "url-scheme is false", "server is disabled"]:
    assert any("Error" in line and reason in line for line in log.splitlines()), reason
assert "Already enabled" in log
assert log.rfind("URL winmux://run/workspace/2 finished with exit 0") < log.rfind("URL winmux://run/workspace/1 finished with exit 0")
assert "Error" in text("nonzero.log") and "Invalid <window-id>" in text("nonzero.log")
cold = json.loads(text("cold-status.json"))
assert cold["permissions"]["setup"] == "waiting-for-permissions"
assert "waiting for Accessibility" in text("cold.log")
print("PASS: CLI/URL examples, Escape, unchanged refusal snapshots, hot reload, FIFO, socket parity, failed-command logging and cold setup refusal")
