import json
from pathlib import Path
import sys

out = Path(sys.argv[1])


def read(label, name):
    return json.loads((out / label / name).read_text())


def normalize(value, window_id, key=None):
    if isinstance(value, list):
        return [normalize(v, window_id, key) for v in value]
    if isinstance(value, dict):
        return {k: normalize(v, window_id, k) for k, v in value.items() if k not in ["pid", "snapshotId", "worldId"]}
    if key in ["window-id", "windowId", "window-ids"] and value == window_id:
        return "owned-window"
    if value == f"pane-{window_id}":
        return "owned-pane"
    return value


base_id = read("base", "windows.json")[0]["window-id"]
feature_id = read("feature", "windows.json")[0]["window-id"]
for name in ["windows.json", "columns.json", "tree.txt", "place.json", "after-boundary.json"]:
    base = normalize(read("base", name), base_id)
    feature = normalize(read("feature", name), feature_id)
    assert base == feature, (name, base, feature)
    print(f"{name}: identical after substituting the owned window/pane id and omitting pid, snapshotId and worldId")
for label in ["base", "feature"]:
    status = read(label, "status.txt")
    assert status["last-error"] is None
    assert status["state"] == "ready"
    assert status["permissions"] == {"accessibility": "granted", "screen-recording": "granted", "setup": "done"}
print("Both builds: ready, no helper error, grants unchanged")
