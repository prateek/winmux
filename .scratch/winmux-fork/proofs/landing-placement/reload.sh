#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
checkout=${1:?checkout directory}
label=${2:?capture label}
proof=$HOME/demo/landing76
captures=$HOME/takes/landing76
W=$checkout/.build/debug/winmux
sed -i '' "s/overflow = 'tab-group/overflow = 'squeeze/" "$proof/config/winmux/winmux.ncl"
sleep 3
$W config status > "$captures/$label-config-before.txt"
$W list-windows --all --search Orange --format '%{window-title}|%{workspace}' > "$captures/$label-search.txt"
$W lens overview --search Orange
sleep 2
# One input process owns the held modifier throughout the config save.
"$proof/keys" 0 "$captures/$label-keys.json" down:alt wait:8 up:alt tap:escape wait:0.3 tap:escape > "$proof/$label-keys.log" 2>&1 &
keys=$!
sleep 1
screencapture -x "$captures/$label-hint-before.png"
screencapture -x -v -V 6 "$captures/$label-reload.mov" > "$proof/$label-recorder.log" 2>&1 &
recorder=$!
sleep 1
sed -i '' "s/workspace.\"1\".columns.count = 3/workspace.\"1\".columns.count = 'off/" "$proof/config/winmux/winmux.ncl"
# Do not issue a read-only command during the save's refresh.
sleep 3
screencapture -x "$captures/$label-hint-after.png"
$W config status > "$captures/$label-config-after.txt"
$W debug-lens-trace --last 1 > "$captures/$label-held-trace.txt"
$W list-columns --json > "$captures/$label-columns-off.json"
wait "$recorder"
wait "$keys"
sleep 1
$W debug-lens-trace --last 1 > "$captures/$label-closed-trace.txt"
$W list-windows --all --format '%{window-title}|%{workspace}|%{window-parent-container-layout}' > "$captures/$label-reload-end.txt"
