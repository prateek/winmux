#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
$W move-node-to-workspace --window-id 186 3
$W focus --window-id 168
sleep 3
$W list-windows --all --format '%{window-id}|%{app-name}|%{app-pid}|%{app-bundle-id}|%{window-title}|%{workspace}' > "$HOME/takes/row/inventory.txt"
(sleep 2; screencapture -x "$HOME/takes/row/pilot-row.png") &
capture=$!
"$HOME/desk/keys" 0 "$HOME/takes/row/pilot.events.json" down:cmd tap:tab wait:2 tap:tab wait:0.6 tap:tab wait:0.6 tap:tab wait:0.6 down:shift tap:tab up:shift wait:0.6 tap:escape up:cmd
wait "$capture"
sleep 1
$W list-windows --focused > "$HOME/takes/row/pilot-end.txt"
