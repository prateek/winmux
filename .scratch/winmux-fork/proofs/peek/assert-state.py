#!/usr/bin/env python3
import json
import sys

with open(sys.argv[1]) as stream:
    session = json.load(stream)[-1]["session"]
for argument in sys.argv[2:]:
    key, value = argument.split("=", 1)
    expected = json.loads(value)
    if session.get(key) != expected:
        raise SystemExit(f"{sys.argv[1]}: {key}: expected {expected!r}, got {session.get(key)!r}")
print("PASS", sys.argv[1], *sys.argv[2:])
