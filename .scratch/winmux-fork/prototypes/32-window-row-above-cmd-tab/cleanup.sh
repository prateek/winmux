#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
sleep 3
$W list-windows --all --format '%{window-id}|%{app-name}' > "$HOME/takes/row/cleanup-start-inventory.txt"
ghostty=$(awk -F'|' '$2 == "Ghostty" {print $1; exit}' "$HOME/takes/row/cleanup-start-inventory.txt")
zed=$(awk -F'|' '$2 == "Zed" {print $1; exit}' "$HOME/takes/row/cleanup-start-inventory.txt")
$W focus --window-id "$ghostty"
$W focus --window-id "$zed"
sleep 2
(sleep 2.7; cliclick c:100,800) &
click=$!
"$HOME/desk/row-film" row/outside-click 7 down:cmd tap:tab wait:3 up:cmd wait:1
wait "$click"
sleep 2
$W list-windows --focused > "$HOME/takes/row/outside-click-focus.txt"
$W doctor > "$HOME/takes/row/final-doctor.txt"
$W list-windows --all > "$HOME/takes/row/final-inventory.txt"
finder=$(awk -F'|' '$2 == "Finder" {print $1; exit}' "$HOME/takes/row/cleanup-start-inventory.txt")
if [ -n "$finder" ]; then $W close --window-id "$finder"; fi
pkill -x window-row || true
pkill -x WinMuxApp || true
sleep 3
for name in Zed zed Ghostty ghostty Safari TextEdit Notes Preview Calculator Updater input-probe; do pkill -x "$name" || true; done
server=$(pgrep -f 'Python -m http.server 8765 --bind 127.0.0.1 --directory' || true)
if [ -n "$server" ]; then kill "$server"; fi
sleep 3
screencapture -x "$HOME/takes/row/clean-desktop.png"
ps -axo pid,command | grep -E 'WinMuxApp|window-row|input-probe|Ghostty.app|Zed.app|Safari.app/Contents/MacOS|TextEdit.app/Contents/MacOS|Notes.app/Contents/MacOS|Preview.app/Contents/MacOS|Calculator.app/Contents/MacOS|desk/Updater' | grep -v grep > "$HOME/takes/row/remaining-owned-processes.txt" || true
