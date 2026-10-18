#!/bin/bash
set -euo pipefail
W="$HOME/winmux/.build/debug/winmux"
for id in 186 178 200 211 168; do $W focus --window-id "$id"; done
sleep 2
for sample in $(seq 1 12); do
  "$HOME/desk/keys" 0 "$HOME/takes/row/sample-$sample.events.json" down:cmd tap:tab wait:0.45 tap:tab wait:0.25 tap:tab wait:0.25 tap:tab wait:0.25 down:shift tap:tab up:shift wait:0.25 tap:escape up:cmd wait:0.35
done
sleep 2
$W list-windows --focused > "$HOME/takes/row/measure-end.txt"
