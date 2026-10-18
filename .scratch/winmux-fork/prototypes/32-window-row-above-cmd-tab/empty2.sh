#!/bin/bash
set -euo pipefail
P="$HOME/row-prototype"
W="$HOME/winmux/.build/debug/winmux"
out="$HOME/takes/row2"
"$W" close --window-id 335
sleep 3
for label in before after; do
    binary="$P/window-row"
    if [ "$label" = before ]; then binary="$P/window-row-before2"; fi
    nohup "$binary" > "$out/$label-empty.jsonl" 2>&1 < /dev/null &
    prototype=$!
    trap 'kill "$prototype" 2>/dev/null || true' EXIT
    sleep 1
    osascript -e 'tell application "Finder" to activate'
    sleep .5
    "$W" focus --window-id 282
    sleep .5
    "$HOME/demo-tools/trace-film" "row2/$label-empty" 6 down:cmd tap:tab wait:1 tap:a wait:.4 tap:escape up:cmd
    kill "$prototype"
    wait "$prototype" 2>/dev/null || true
done
