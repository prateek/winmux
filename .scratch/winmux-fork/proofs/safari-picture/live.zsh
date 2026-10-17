#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
tree=${1:?source tree}
label=${2:?label}
proof=${0:A:h}
out=$HOME/safari-captures/$label
W=$tree/.build/debug/winmux
mkdir -p "$out"
swiftc "$proof/windows.swift" -o "$HOME/desk/safari-windows"
nohup /usr/bin/log stream --level debug --style compact --predicate 'category == "lens"' > "$out/lens.log" 2>&1 &
logger=$!
trap 'kill $logger 2>/dev/null || true' EXIT
if [[ ${OPEN_NEW_WINDOW:-0} == 1 ]]; then
    "$W" list-windows --all --format '%{window-id} %{app-name}' | awk '$2 == "Safari" { print $1 }' | sort > "$out/before-new.ids"
    open -a Safari "http://localhost:8765/lenses.html?capture-check=$label"
    sleep 12
    "$W" list-windows --all --format '%{window-id} %{app-name}' | awk '$2 == "Safari" { print $1 }' | sort > "$out/after-new.ids"
    comm -13 "$out/before-new.ids" "$out/after-new.ids" > "$out/new.ids"
    [[ -s "$out/new.ids" ]] || { echo 'New Safari window was not registered' >&2; exit 1; }
fi
for workspace in 2 3 4 1; do "$W" workspace "$workspace" >/dev/null; sleep 3; done
sleep 10
"$W" list-windows --all --format '%{window-id} | %{app-name} | %{window-title} | %{workspace}' > "$out/entries.txt"
while IFS= read -r id; do
    "$W" focus --window-id "$id" >/dev/null
    sleep 3
done < <("$W" list-windows --all --format '%{window-id} %{app-name}' | awk '$2 == "Safari" { print $1 }')
"$W" workspace 1 >/dev/null
sleep 3
"$W" agent query --path "$out/world.json"
cliclick m:1860,1020
for section in workspace app none strip; do
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$out/$section.time.txt"
    "$HOME/desk/safari-windows" > "$out/$section-safari.txt"
    if [[ $section == strip ]]; then
        "$HOME/desk/keys" 0 "$out/strip.events.json" down:cmd tap:tab wait:12 tap:escape up:cmd &
        keys=$!
    else
        "$W" lens --filter true --presentation grid --tile card --sections "$section"
    fi
    sleep 8
    screencapture -x "$out/$section.png"
    "$HOME/desk/safari-windows" > "$out/$section-safari-after.txt"
    "$W" debug-lens-trace --json --last 1 > "$out/$section.trace.json"
    python3 - "$out/$section.trace.json" "$section" <<'CHECK'
import json, sys
trace = json.load(open(sys.argv[1]))[-1]
session = trace["session"]
presentation = "strip" if sys.argv[2] == "strip" else "grid"
assert session["active"] and session["presentation"] == presentation, trace
assert session["search"] == "", session
print(f"checked {presentation}: active, empty Search, selected {session['selectedId']}")
CHECK
    if [[ $section == strip ]]; then wait "$keys"; else cliclick kp:esc w:500; fi
done
if [[ -f "$out/new.ids" ]]; then
    while IFS= read -r id; do "$W" close --window-id "$id"; done < "$out/new.ids"
    sleep 3
fi
"$W" list-workspaces --focused > "$out/ending-workspace.txt"
"$W" list-windows --all --json > "$out/ending-windows.json"
