#!/usr/bin/env python3
import json
from pathlib import Path
import sys

out = Path(sys.argv[1])
records = [line.split("|") for line in (out / "original.windows.txt").read_text().splitlines()]
zed = int(next(row[0] for row in records if row[1] == "Zed"))
ghosts = sorted(int(row[0]) for row in records if row[1] == "Ghostty")
notes = int(next(row[0] for row in records if row[1] == "Notes"))
calculator = int(next(row[0] for row in records if row[1] == "Calculator"))


def snapshot(name):
    return json.loads((out / (name + ".tree.json")).read_text())


def tree(name, workspace="1"):
    return next(row["tree"] for row in snapshot(name)["reasoning"]["rawTrees"] if row["workspace"] == workspace)


def window_ids(node):
    if node["kind"] == "window":
        return [node["windowId"]]
    if node["kind"] == "tabGroup":
        return node["tabs"]
    return [window for child in node["children"] for window in window_ids(child)]


def pair(name, direction, ids):
    child = tree(name)["children"][0]
    assert child["kind"] == "split", (name, child)
    assert child["direction"] == direction, (name, child)
    assert window_ids(child) == ids, (name, child)


pair("pair-side-by-side", "horizontal", [ghosts[1], zed])
pair("pair-stacked", "vertical", [zed, ghosts[1]])
tabs = tree("tab-group")["children"][0]
assert tabs["kind"] == "tabGroup" and tabs["tabs"] == [zed, ghosts[0]], tabs
assert tree("menu-tabs")["children"][0]["tabs"] == [ghosts[1], zed]
pair("menu-back-to-split", "horizontal", [ghosts[1], zed])
pair("menu-stacked", "vertical", [ghosts[1], zed])
assert tree("menu-stacked")["direction"] == "horizontal"
pair("glyph-flip", "horizontal", [ghosts[1], zed])
assert tree("glyph-flip")["direction"] == "vertical"
assert [node["windowId"] for node in tree("menu-ungroup")["children"]] == [ghosts[1], zed, ghosts[0]]
pair("swap", "vertical", [ghosts[0], ghosts[1]])
assert tree("swap")["children"][1]["windowId"] == zed
assert any(row["windowId"] == calculator and row["layout"] != "floating" for row in snapshot("floating-source")["inventory"]["windows"])
column = tree("column-child", "2")
assert column["direction"] == "horizontal" and len(column["children"]) == 3
assert window_ids(column["children"][0]) == [notes, ghosts[1]]
columns = json.loads((out / "column-child.columns.json").read_text())
assert [row["width"] for row in columns] == [0.28, 0.44, 0.28]
assert tree("option-release")["direction"] == "horizontal"
assert [node["windowId"] for node in tree("option-release")["children"]] == [zed, ghosts[1], ghosts[0]]
for name in ["before", "plain", "layout-vertical"]:
    assert snapshot("base-" + name)["reasoning"]["rawTrees"] == snapshot("feature-" + name)["reasoning"]["rawTrees"], name
    assert sorted((out / ("base-" + name + ".windows.txt")).read_text().splitlines()) == sorted((out / ("feature-" + name + ".windows.txt")).read_text().splitlines()), name
    assert snapshot("base-verified-" + name)["reasoning"]["rawTrees"] == snapshot("feature-verified-" + name)["reasoning"]["rawTrees"], name
    assert sorted((out / ("base-verified-" + name + ".windows.txt")).read_text().splitlines()) == sorted((out / ("feature-verified-" + name + ".windows.txt")).read_text().splitlines()), name
assert (out / "base-plain.input.json").read_text() == (out / "feature-plain.input.json").read_text()
assert (out / "base-plain.columns.json").read_text() == (out / "feature-plain.columns.json").read_text()
assert (out / "base-verified-plain.input.json").read_text() == (out / "feature-verified-plain.input.json").read_text()
assert (out / "base-verified-plain.columns.json").read_text() == (out / "feature-verified-plain.columns.json").read_text()
assert snapshot("base-repeat-plain")["reasoning"]["rawTrees"] == snapshot("feature-repeat-plain")["reasoning"]["rawTrees"]
assert (out / "base-repeat-plain.input.json").read_text() == (out / "feature-repeat-plain.input.json").read_text()
pair("final-side-by-side", "horizontal", [ghosts[1], zed])
assert tree("final-menu-tabs")["children"][0]["tabs"] == [ghosts[1], zed]
pair("final-menu-back", "horizontal", [ghosts[1], zed])
pair("final-glyph", "vertical", [ghosts[1], zed])
assert tree("final-glyph")["direction"] == "horizontal"
assert [node["windowId"] for node in tree("final-ungroup")["children"]] == [ghosts[1], zed, ghosts[0]]
assert tree("menu-flatten")["tabs"] == [zed, ghosts[0], ghosts[1]]
print("PASS: sidebar split/tab/swap, all container actions, glyph cascade, floating tile, Column slot/widths, stationary Option release, and identical base/feature plain input, inventory, trees and Columns")

for build in ["base", "feature"]:
    names = [build + "-stress-plain"] + [build + "-stress-" + str(index) for index in range(1, 5)]
    if all((out / (name + ".tree.json")).exists() for name in names):
        succeeded = []
        for name in names:
            node = tree(name)
            succeeded.append(node["direction"] == "horizontal" and
                all(child["kind"] == "window" for child in node["children"]) and
                window_ids(node) == [ghosts[1], zed, ghosts[0]])
        print(f"Historical undrained-input observations: {build} {sum(succeeded)}/{len(names)} made siblings; held-input takes: " +
              ", ".join(name for name, success in zip(names, succeeded) if not success))

if len(sys.argv) > 2:
    prefix = sys.argv[2]
    names = sorted(path.name.removesuffix(".input.json") for path in out.glob(prefix + "-*.input.json"))
    assert names, prefix
    failed = []
    for name in names:
        node = tree(name)
        if "verified" in prefix:
            buttons = json.loads((out / (name + ".buttons.json")).read_text())
            assert not buttons["before"]["leftDown"] and not buttons["after"]["leftDown"], (name, buttons)
        if not (node["direction"] == "horizontal" and all(child["kind"] == "window" for child in node["children"]) and
                window_ids(node) == [ghosts[1], zed, ghosts[0]]):
            failed.append(name)
    if failed:
        raise SystemExit("FAIL: plain drops did not make siblings: " + ", ".join(failed))
    print(f"PASS: {len(names)}/{len(names)} plain drops made siblings ({prefix})")
