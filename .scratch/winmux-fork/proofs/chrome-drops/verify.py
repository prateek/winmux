import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
results = sorted(root.glob("*.result.json"))
assert results


def leaves(node):
    if "windowId" in node:
        return [node["windowId"]]
    return [window for child in node.get("children", []) for window in leaves(child)]


for path in results:
    result = json.loads(path.read_text())
    name = result["name"]
    tree = json.loads((root / (name + "-after.tree.json")).read_text())
    windows = tree["inventory"]["windows"]
    assert len(windows) == 15, name
    moved = next(w for w in windows if w["windowId"] == result["windowId"])
    assert moved["workspace"] == result["to"], name
    listed = {}
    for line in (root / (name + "-after.windows.txt")).read_text().splitlines():
        window_id, title, workspace, layout = line.split("|")
        listed[int(window_id)] = (title, workspace, layout)
    assert listed == {w["windowId"]: (w["title"], w["workspace"], w["layout"]) for w in windows}, name
    for workspace in tree["reasoning"]["rawTrees"]:
        assert sorted(leaves(workspace["tree"])) == sorted(w["windowId"] for w in windows if w["workspace"] == workspace["workspace"]), name
    for suffix in ["-ready", "-before", "-preview", "-after"]:
        assert (root / (name + suffix + ".png")).is_file(), (name, suffix)
    print(f"{name}: {result['title']} {result['from']} -> {result['to']}; 15 windows; inventory/list/tree agree")

for suffix in ["row-edge", "title-edge", "row-visible", "title-visible", "title-new"]:
    base = json.loads((root / ("base-" + suffix + ".result.json")).read_text())
    feature = json.loads((root / ("feature-" + suffix + ".result.json")).read_text())
    for field in ["title", "from", "to", "source", "target", "viewport"]:
        assert base[field] == feature[field], (suffix, field, base[field], feature[field])
print("Five unchanged base/feature cases have identical inputs and destination summaries")

for kind in ["row", "title"]:
    base = json.loads((root / (f"base-{kind}-pager.result.json")).read_text())
    fixed = json.loads((root / (f"fixed-{kind}-pager.result.json")).read_text())
    for field in ["title", "from", "source", "target", "viewport"]:
        assert base[field] == fixed[field], (kind, field)
    assert base["to"] == "5" and fixed["to"] == "2", kind
print("Both paired pager cases use identical inputs: base moves to 5; fixed stays on 2")
