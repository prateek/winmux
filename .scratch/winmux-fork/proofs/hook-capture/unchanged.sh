#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euo pipefail
tree=$1
label=$2
out="$HOME/takes/hook-capture/$label"
mkdir -p "$out"
w="$tree/.build/debug/winmux"
bash "$HOME/hook-proof/start.sh" "$tree" > "$out/start.txt"
open -a Ghostty
sleep 5
"$w" list-windows --all --json > "$out/windows.json"
"$w" list-columns --json > "$out/columns.json"
"$w" agent query > "$out/tree.txt"
screencapture -x "$out/arrival.png"
id=$(python3 -c 'import json,sys; a=json.load(open(sys.argv[1])); print(next(w["window-id"] for w in a if w["app-name"] == "Ghostty"))' "$out/windows.json")
"$w" place --dry-run --window-id "$id" --json > "$out/place.json"
"$w" move-node-to-column 3 --window-id "$id"
"$w" move right --window-id "$id"
"$w" list-columns --json > "$out/after-boundary.json"
"$w" config status > "$out/status.txt"
screencapture -x "$out/boundary.png"
"$w" close --window-id "$id"
sleep 3
pkill -x WinMuxApp
sleep 3
pkill -x ghostty || true
