import json
import os
from pathlib import Path
import subprocess
import sys
import time

HOME = Path.home()
OUT = HOME / "takes/group-drag"
CLI = Path(os.environ.get("WINMUX_CLI", HOME / "winmux/.build/debug/winmux"))
OUT.mkdir(parents=True, exist_ok=True)
COMMANDS = []


def run(*args):
    COMMANDS.append(list(map(str, args)))
    result = subprocess.run(list(map(str, args)), capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError((args, result.stdout, result.stderr))
    return result.stdout


def cli(*args):
    return run(CLI, *args)


def save(name, suffix, value):
    (OUT / (name + suffix)).write_text(value)


def snapshot(name):
    time.sleep(5)
    save(name, ".windows.txt", cli("list-windows", "--all", "--format", "%{window-id}|%{window-title}|%{workspace}|%{window-layout}"))
    tree = json.loads(cli("agent", "query"))
    save(name, ".tree.json", json.dumps(tree, indent=2))
    run("screencapture", "-x", OUT / (name + ".png"))
    pid = run("pgrep", "-x", "WinMuxApp").strip()
    save(name, ".ui.json", run(HOME / "demo/ui", pid))
    return tree


def window(window_id):
    return {"kind": "window", "windowId": window_id}


def stage(kind, name):
    inventory = json.loads(cli("agent", "query"))
    ids = {w["title"]: w["windowId"] for w in inventory["inventory"]["windows"]}
    assert set(ids) == {"Red", "Blue", "Green", "Yellow", "Violet"}, ids
    cli("column-count", "off", "--workspace", "1")
    data = json.loads(cli("agent", "query"))
    if kind in ("A", "plain"):
        used, parked = ["Red", "Blue", "Green", "Violet"], ["Yellow"]
    else:
        used, parked = ["Red", "Blue", "Green", "Yellow", "Violet"], []
    layouts = [{"name": "1", "layout": {"kind": "split", "direction": "horizontal", "children": [window(ids[x]) for x in used]}, "focus": {"windowId": ids["Red"]}}]
    if parked:
        layouts.append({"name": "3", "layout": window(ids[parked[0]])})
    data["edit"] = {"operations": [], "layout": {"workspaces": layouts}}
    path = OUT / (name + "-reset.json")
    path.write_text(json.dumps(data, indent=2))
    cli("agent", "apply", "--path", path)
    cli("workspace", "1")
    cli("join-with", "--window-id", ids["Blue"], "right")
    if kind == "B":
        cli("layout", "--window-id", ids["Blue"], "tab-group")
        cli("join-with", "--window-id", ids["Yellow"], "left")
        cli("column-count", "3", "--workspace", "1")
        cli("move-node-to-column", "--window-id", ids["Red"], "2")
        cli("column-count", "off", "--workspace", "1")
    else:
        cli("join-with", "--window-id", ids["Red"], "right")
        cli("layout", "--window-id", ids["Red"], "tab-group")
    cli("focus", "--window-id", ids["Red"] if kind == "plain" else ids["Blue"])
    tree = snapshot(name + "-staged")
    return ids, tree


def drag(name, sx, sy, tx, ty):
    run("screencapture", "-x", OUT / (name + "-before.png"))
    commands = [f"m:{sx},{sy}", "w:1000", f"dd:{sx},{sy}", "w:200", f"dm:{sx+12},{sy+5}", "w:300", f"dm:{tx},{ty}", "w:3000", f"du:{tx},{ty}"]
    save(name, ".input.json", json.dumps(commands))
    arguments = ["/opt/homebrew/bin/cliclick", *commands]
    COMMANDS.append(arguments)
    pointer = subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(3.3)
    run("screencapture", "-x", OUT / (name + "-preview.png"))
    stdout, stderr = pointer.communicate(timeout=15)
    if pointer.returncode:
        raise RuntimeError((stdout, stderr))
    return snapshot(name + "-after")


def button(tree_name, description):
    rows = json.loads((OUT / (tree_name + ".ui.json")).read_text())
    matches = [r for r in rows if r["role"] == "AXButton" and r["description"] == description and r["height"] < 30 and r["x"] < 320]
    assert len(matches) == 1, (description, matches)
    return matches[0]


def center(row):
    return round(row["x"] + row["width"] / 2), round(row["y"] + row["height"] / 2)


def scenario(name, kind):
    ids, tree = stage(kind, name)
    leaves = [ids[x] for x in (["Red", "Blue", "Green", "Yellow"] if kind == "B" else ["Red", "Blue", "Green"])]
    active = "Red" if kind == "plain" else "Blue"
    label = f"{active}, {len(leaves)}"
    rows = json.loads((OUT / (name + "-staged.ui.json")).read_text())
    handle = min((r for r in rows if r["description"] == "Focus Tab Group"), key=lambda r: r["y"])
    tree = drag(name + "-tile", *center(handle), 1040, 360)
    root = next(t["tree"] for t in tree["reasoning"]["rawTrees"] if t["workspace"] == "1")
    assert root["children"][0]["windowId"] == ids["Violet"], root
    group = button(name + "-tile-after", label)
    target = button(name + "-tile-after", "Violet")
    tree = drag(name + "-row", *center(group), round(target["x"] + target["width"] / 2), round(target["y"] + 4))
    root = next(t["tree"] for t in tree["reasoning"]["rawTrees"] if t["workspace"] == "1")
    assert root["children"][-1]["windowId"] == ids["Violet"], root
    cli("move-node-to-workspace", "--window-id", ids["Violet"], "Destination")
    snapshot(name + "-workspace-ready")
    group = button(name + "-workspace-ready", label)
    target = button(name + "-workspace-ready", "Destination")
    tree = drag(name + "-workspace", *center(group), *center(target))
    windows = {w["windowId"]: w for w in tree["inventory"]["windows"]}
    assert all(windows[i]["workspace"] == "Destination" for i in leaves), windows
    group_ids = {windows[i].get("tabGroupId") for i in leaves}
    assert len(group_ids) == 1 and None not in group_ids, group_ids
    summary = {"windows": [{"title": w["title"], "workspace": w["workspace"], "layout": w["layout"], "group": w.get("tabGroupId")} for w in windows.values()], "trees": tree["reasoning"]["rawTrees"]}
    save(name, ".summary.json", json.dumps(summary, indent=2))


mode, name, *args = sys.argv[1:]
try:
    if mode == "stage":
        stage(args[0], name)
    elif mode == "snapshot":
        snapshot(name)
    elif mode == "drag":
        drag(name, *map(int, args))
    elif mode == "scenario":
        scenario(name, args[0])
    else:
        raise SystemExit("stage NAME A|B|plain; snapshot NAME; drag NAME SX SY TX TY")
finally:
    save(name, ".commands.json", json.dumps(COMMANDS, indent=2))
