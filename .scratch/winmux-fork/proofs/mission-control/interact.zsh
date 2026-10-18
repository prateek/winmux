#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
label=$1
W=$2/.build/debug/winmux
out=$HOME/takes/mission-control/$label
mkdir -p "$out"
$W workspace 2
sleep 3
target=$($W list-windows --all --json | python3 -c 'import json,sys; print(next(w["window-id"] for w in json.load(sys.stdin) if w["window-title"] == "Lenses and Search"))')
$W focus --window-id "$target"
sleep 2
cliclick m:1880,1070
screencapture -x -v "$out/interaction.mov" &
recorder=$!
trap 'kill -INT "$recorder" 2>/dev/null || true; wait "$recorder" || true' EXIT
sleep 2
cliclick c:920,60
sleep 2
$W list-windows --focused --json > "$out/tab-click.json"
screencapture -x "$out/tab-click.png"
cliclick c:1180,60
sleep 2
$W list-columns > "$out/divider-before.txt"
cliclick dd:1390,500 dm:1430,500 du:1430,500
sleep 2
$W list-columns > "$out/divider-after.txt"
screencapture -x "$out/divider-after.png"
cliclick dd:1430,500 dm:1390,500 du:1390,500
sleep 2
cliclick m:5,500
sleep 2
cliclick c:100,440
sleep 2
$W list-workspaces --focused > "$out/sidebar-click.txt"
screencapture -x "$out/sidebar-click.png"
$W workspace 2
sleep 3
cliclick m:1880,1070
screencapture -x "$out/interaction-end.png"
$W list-windows --all --json > "$out/interaction-windows-end.json"
$W list-columns > "$out/interaction-columns-end.txt"
kill -INT "$recorder"
wait "$recorder" || true
trap - EXIT
