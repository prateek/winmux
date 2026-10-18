#!/usr/bin/env python3
"""Summarize the first twelve sessions in a prototype log."""
import json
import statistics
import sys
from collections import Counter

records = []
for line in open(sys.argv[1]):
    try:
        records.append(json.loads(line))
    except ValueError:
        pass


def stats(values):
    return {"n": len(values), "min_ms": round(min(values), 3),
            "median_ms": round(statistics.median(values), 3), "max_ms": round(max(values), 3)}


sample = [r for r in records if 1 <= r.get("session", 0) <= 12]
for kind in ["first", "tab", "shift-tab"]:
    values = [r["ms"] for r in sample if r["event"] == "highlight-latency" and r["kind"] == kind]
    print(kind, json.dumps(stats(values)))
print("snapshot", json.dumps(stats([r["ms"] for r in sample if r["event"] == "snapshot"])))
first_keys = {}
pending = None
rows = {}
for record in records:
    if record["event"] == "input" and record["type"] == 10 and record["code"] == 48 and not record["active"]:
        pending = record["stamp"]
    if record["event"] == "session-open" and pending is not None:
        first_keys[record["session"]] = pending
        pending = None
    if record["event"] == "row-show":
        rows.setdefault(record["session"], record["time"])
values = [(rows[s] - first_keys[s]) * 1000 for s in range(1, 13) if s in rows and s in first_keys]
print("first-row-ordered", json.dumps(stats(values)))
snapshots = Counter(r["session"] for r in records if r["event"] == "snapshot")
sessions = [r["session"] for r in records if r["event"] == "session-open"]
print("snapshots-per-session", dict(snapshots))
print("sessions-without-exactly-one-snapshot", [s for s in sessions if snapshots[s] != 1])
print("overlap", sum(r["intersects"] for r in records if r["event"] == "row-show"))
print("key-panel", sum(r["key"] for r in records if r["event"] == "row-show"))
print("swallowed-types", sorted({r["type"] for r in records if r["event"] == "swallow"}))
print("swallowed-codes", sorted({r["code"] for r in records if r["event"] == "swallow"}))
