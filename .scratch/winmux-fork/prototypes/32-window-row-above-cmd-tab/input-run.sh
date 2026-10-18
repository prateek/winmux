#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
out="$HOME/takes/row"
swiftc "$HOME/row-prototype/input-probe.swift" -o "$HOME/row-prototype/input-probe"
nohup "$HOME/row-prototype/input-probe" > "$out/input-normal.log" 2>&1 &
probe=$!
sleep 5
"$HOME/winmux/.build/debug/winmux" list-windows --all --format '%{window-id}|%{window-title}' > "$out/input-normal-inventory.txt"
id=$(awk -F'|' '/Input canary/ {print $1}' "$out/input-normal-inventory.txt")
"$HOME/winmux/.build/debug/winmux" focus --window-id "$id"
"$HOME/desk/keys" 0 "$out/canary-before.events.json" down:cmd tap:a up:cmd wait:0.3 tap:right
sleep 1
"$HOME/desk/row-film" row/key-canary 7 down:cmd tap:tab wait:1 tap:a wait:0.8 tap:escape up:cmd wait:0.5
sleep 1
"$HOME/desk/keys" 0 "$out/canary-after.events.json" down:cmd tap:a up:cmd
sleep 1
kill "$probe"
sleep 2
nohup "$HOME/row-prototype/input-probe" --secure > "$out/input-secure.log" 2>&1 &
probe=$!
sleep 5
"$HOME/winmux/.build/debug/winmux" list-windows --all --format '%{window-id}|%{window-title}' > "$out/input-secure-inventory.txt"
id=$(awk -F'|' '/Input canary/ {print $1}' "$out/input-secure-inventory.txt")
"$HOME/winmux/.build/debug/winmux" focus --window-id "$id"
(sleep 2.5; "$HOME/row-prototype/dock-probe" > "$out/secure-dock-tree.txt"; screencapture -x "$out/secure-held.png") &
capture=$!
"$HOME/desk/row-film" row/secure-input 8 down:cmd tap:tab wait:1 tap:a wait:0.6 tap:tab wait:0.6 down:shift tap:tab up:shift wait:0.6 tap:escape up:cmd wait:1
wait "$capture"
sleep 1
screencapture -x "$out/secure-result.png"
kill "$probe"
sleep 3
"$HOME/winmux/.build/debug/winmux" list-windows --all > "$out/after-input-inventory.txt"
"$HOME/winmux/.build/debug/winmux" list-windows --focused > "$out/after-input-focus.txt"
