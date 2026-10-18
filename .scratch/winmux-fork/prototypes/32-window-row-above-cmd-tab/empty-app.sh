#!/bin/bash
set -euo pipefail
W="$HOME/winmux/.build/debug/winmux"
$W close --window-id 219
sleep 3
osascript -e 'tell application "Finder" to activate'
sleep 1
$W focus --window-id 168
sleep 2
$W list-windows --all > "$HOME/takes/row/empty-app-inventory.txt"
"$HOME/desk/row-film" row/empty-app 6 down:cmd tap:tab wait:1.5 tap:a wait:0.3 tap:escape up:cmd wait:1
sleep 2
$W list-windows --focused > "$HOME/takes/row/empty-app-focus.txt"
