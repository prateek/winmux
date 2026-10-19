import json
from pathlib import Path
import sys

out = Path(sys.argv[1])


def lines(name):
    return [json.loads(line) for line in (out / name).read_text().splitlines()]


def read(name):
    return json.loads((out / name).read_text())


arrival = lines("live-arrival.jsonl")
assert len(arrival) == 2
assert [r["hook"] for r in arrival] == ["arrive", "columns.place"]
assert arrival[0]["window-id"] == arrival[1]["window-id"]
window_id = arrival[0]["window-id"]
debug_text = "\n".join(line.split(" ||| ", 1)[1] for line in (out / "live-arrival-debug.txt").read_text().splitlines() if " ||| " in line)
debug = json.loads(debug_text)["WinMux.windowRecord"]
for record in arrival:
    print(record["hook"], "windowRecord comparison:")
    assert record["args"][0].keys() == debug.keys()
    for key, value in debug.items():
        before = record["args"][0][key]
        if before != value:
            print(f"  {key}: captured {before!r}; debug-windows {value!r}")
            assert key in ["lastFocusedSeq", "title"], (key, before, value)
            if key == "lastFocusedSeq":
                assert before == 0 and value > 0
            else:
                assert before == "" and value == "Hook capture"
        else:
            print(f"  {key}: equal")
assert window_id in read("live-arrival-columns.json")[1]["window-ids"]
failure = lines("live-failure.jsonl")[-1]
assert failure["hook"] == "columns.place"
assert failure["result"] is None and "capture live failure" in failure["error"]
assert any(failure["window-id"] in c["window-ids"] for c in read("live-failure-columns.json"))
print("Raised hook: null result, helper error, window placed by built-in policy")
invalid = lines("live-out-of-range.jsonl")[-1]
assert invalid["result"] == {"column": 7, "overflow": "tab-group"}
assert invalid["error"] is None
assert "exceeds count" in read("live-out-of-range-status.json")["last-error"]
assert any(invalid["window-id"] in c["window-ids"] for c in read("live-out-of-range-columns.json"))
print("Column 7: accepted answer, null capture error, later failure in config status, built-in placement")
records = lines("live-on.jsonl")
events = lines("events.jsonl")
for event in events:
    assert event.pop("_event") == "hook-called"
assert records == events, (len(records), len(events))
assert len(records) == 8, len(records)
assert records[2]["hook"] == "columns.place"
assert records[3]["hook"] == "columns.move-boundary" and records[3]["args"][-1] is True
print(f"File and hook-called stream: {len(records)} identical records; dry-run and boundary move add one each")
assert len(read("live-off-windows.json")) == 4
assert not (out / "off-events.jsonl").read_text()
print("Capture off: fourth window managed, file unchanged, hook-called silent")
