#!/bin/bash
set -euo pipefail
W="$HOME/winmux/.build/debug/winmux"
for id in 186 178 168; do $W focus --window-id "$id"; done
sleep 2
"$HOME/desk/row-film" row/navigation 9 down:cmd tap:tab wait:0.7 tap:a wait:0.3 tap:right wait:0.3 tap:left wait:0.3 tap:tab wait:0.3 down:shift tap:tab up:shift wait:0.3 tap:down wait:0.3 tap:up wait:0.3 tap:escape up:cmd wait:1
sleep 2
$W list-windows --focused > "$HOME/takes/row/navigation-focus.txt"
