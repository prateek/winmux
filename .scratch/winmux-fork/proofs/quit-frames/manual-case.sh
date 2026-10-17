#!/bin/bash
set -euo pipefail
for app in Zed zed Ghostty ghostty Safari Notes; do pkill -x "$app" || true; done
sleep 3
cd "$HOME/quit-tools"
swiftc reshape.swift -o reshape
bash prepare-case.sh manual
W=$HOME/winmux/.build/debug/winmux
out=$HOME/quit-proof/manual
red=$(awk -F'|' '$3 == "Red" {print $1}' "$out/tiled.txt")
late=$(awk -F'|' '$3 == "Late" {print $1}' "$out/tiled.txt")
pid=$(pgrep -x stage)
$W layout --window-id "$red" floating
$W layout --window-id "$late" floating
"$HOME/quit-tools/reshape" "$pid" Red 400 220 600 280
"$HOME/quit-tools/reshape" "$pid" Late 650 320 400 250
sleep 4
$W reload-config
sleep 4
$W agent query --path "$out/model.json"
sleep 2
"$HOME/quit-tools/frames" > "$out/before-quit.json"
screencapture -x "$out/before-quit.png"
bash finish-case.sh manual event
