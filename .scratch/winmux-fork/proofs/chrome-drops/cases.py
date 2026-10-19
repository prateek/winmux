import json
import sys
import time
import live


def case(prefix, kind, destination, pager_workspace):
    name = f"{prefix}-{kind}-{destination}"
    live.stage(name + "-reset")
    source_workspace = "4" if destination == "new" else "2"
    title = "White" if destination == "new" else "Yellow"
    if kind == "title" and destination == "pager":
        staged = json.loads((live.OUT / (name + "-reset-staged.tree.json")).read_text())
        source_id = next(w["windowId"] for w in staged["inventory"]["windows"] if w["title"] == title)
        live.cli("move-node-to-workspace", "--window-id", source_id, "1")
        live.cli("move-node-to-workspace", "--window-id", source_id, "2")
    live.cli("workspace", source_workspace)
    live.run(live.CLICK, "m:160,400", "w:400")
    live.run(live.HOME / "demo/scroll", "2000")
    time.sleep(1)
    live.run(live.HOME / "demo/scroll", "-2000" if destination == "new" else "-42")
    before = live.snapshot(name + "-ready")
    rows = json.loads((live.OUT / (name + "-ready.ui.json")).read_text())
    window = next(w for w in before["inventory"]["windows"] if w["title"] == title)
    if kind == "row":
        row = next(r for r in rows if r["role"] == "AXButton" and r["description"] == title and r["height"] == 24)
        sx, sy = round(row["x"] + row["width"] / 2), round(row["y"] + 12)
    else:
        frame = window["frame"]
        sx, sy = round(frame["x"] + frame["width"] / 2), round(frame["y"] + 16)
    viewport = next(r for r in rows if r["role"] == "AXScrollArea" and r["x"] == 0)
    if destination == "pager":
        tx, ty = 160, round(viewport["y"] + viewport["height"] + 7)
        expected = pager_workspace
    else:
        label = {"edge": "Workspace 5", "visible": "Workspace 3", "new": "New Workspace"}[destination]
        target = next(r for r in rows if r["role"] == "AXButton" and r["description"] == label and r["height"] > 30)
        tx, ty = 160, round(target["y"] + 16)
        expected = {"edge": "5", "visible": "3", "new": None}[destination]
    assert 52 < sy < 573 or kind == "title", (sx, sy)
    live.drag(name, sx, sy, tx, ty)
    after = json.loads((live.OUT / (name + "-after.tree.json")).read_text())
    moved = next(w for w in after["inventory"]["windows"] if w["windowId"] == window["windowId"])
    if expected is None:
        assert moved["workspace"] not in ["1", "2", "3", "4", "5"], moved
    else:
        assert moved["workspace"] == expected, (name, moved, expected)
    summary = {"name": name, "title": title, "windowId": window["windowId"], "from": source_workspace, "to": moved["workspace"], "source": [sx, sy], "target": [tx, ty], "viewport": viewport}
    (live.OUT / (name + ".result.json")).write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary), flush=True)


prefix, pager_workspace, *selection = sys.argv[1:]
cases = [("row", "pager"), ("title", "pager")] if selection == ["pager"] else [("row", "edge"), ("title", "edge"), ("row", "visible"), ("title", "visible"), ("title", "new")]
for kind, destination in cases:
    case(prefix, kind, destination, pager_workspace)
