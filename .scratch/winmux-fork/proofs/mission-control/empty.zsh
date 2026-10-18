#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
label=$1
root=$2
cd "$root"
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
out=$HOME/takes/mission-control/$label
mkdir -p "$out"
nohup .build/debug/WinMuxApp > "$out/empty-outline-app.log" 2>&1 &
sleep 25
W=$root/.build/debug/winmux
$W workspace 2
sleep 3
$W column-count 4
$W focus-column 4
sleep 3
~/mission-control/parking save "$out/empty-outline-frames.json"
screencapture -x "$out/empty-outline.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control-empty-outline.png"
~/mission-control/parking ax > "$out/mission-control-empty-outline-ax.txt"
~/mission-control/arrow-chord up
cliclick ku:fn
sleep 2
$W column-count 3
$W reload-config
sleep 3
target=$($W list-windows --all --json | python3 -c 'import json,sys; print(next(w["window-id"] for w in json.load(sys.stdin) if w["window-title"] == "Lenses and Search"))')
$W focus --window-id "$target"
sleep 3
$W list-windows --all --json > "$out/final-windows.json"
$W list-workspaces --focused > "$out/final-workspace.txt"
$W list-columns > "$out/final-columns.txt"
screencapture -x "$out/final-desktop.png"
pkill -x WinMuxApp
sleep 3
