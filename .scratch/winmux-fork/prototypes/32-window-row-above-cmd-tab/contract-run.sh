#!/bin/bash
set -euo pipefail
P="$HOME/row-prototype"
label=${1:-after}
binary="$P/window-row"
if [ "$label" = before ]; then binary="$P/window-row-before2"; fi
swiftc "$P/key-contract.swift" -o "$P/key-contract"
nohup "$binary" > "$HOME/takes/row2/$label-contract.jsonl" 2>&1 < /dev/null &
prototype=$!
trap 'kill "$prototype" 2>/dev/null || true' EXIT
sleep 1
for scenario in escape pairs fade new-session; do
    echo "$scenario"
    "$HOME/winmux/.build/debug/winmux" focus --window-id 309
    "$HOME/winmux/.build/debug/winmux" focus --window-id 282
    sleep .5
    "$P/key-contract" "$scenario"
    sleep .5
done
kill "$prototype"
wait "$prototype" 2>/dev/null || true
