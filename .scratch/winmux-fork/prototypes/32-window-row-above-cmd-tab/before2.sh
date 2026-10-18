#!/bin/bash
set -euo pipefail
P="$HOME/row-prototype"
K="$HOME/desk/keys"
mkdir -p "$HOME/takes/row2"
baseline=${1:?Pass the original window-row.swift source from commit 34a2daab}
swiftc "$baseline" -o "$P/window-row-before2"
swiftc "$P/dock-probe.swift" -o "$P/dock-probe"
nohup "$P/window-row-before2" > "$HOME/takes/row2/before.jsonl" 2>&1 < /dev/null &
prototype=$!
trap 'kill "$prototype" 2>/dev/null || true' EXIT
sleep 2
(sleep 0.7; "$P/dock-probe" > "$HOME/takes/row2/button-attributes.txt") &
probe=$!
"$K" 0 "$HOME/takes/row2/before-escape.events.json" down:cmd tap:tab wait:1 tap:a wait:0.2 tap:escape wait:0.02 tap:a tap:tab tap:right up:cmd
wait "$probe"
for n in $(seq 1 8); do
  "$K" 0 "$HOME/takes/row2/before-fade-$n.events.json" down:cmd tap:tab wait:0.35 up:cmd wait:0.005 down:cmd wait:0.02 tap:a up:cmd wait:0.4
done
kill "$prototype"
wait "$prototype" || true
