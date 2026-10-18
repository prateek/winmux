#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
for id in 186 178 200 211 168; do $W focus --window-id "$id"; done
sleep 2
cp "$HOME/winmux/.claude/skills/demo/film" "$HOME/desk/row-film"
chmod +x "$HOME/desk/row-film"
cliclick m:1870,1040
(sleep 4.2; screencapture -x "$HOME/takes/row/hero-row.png"; sleep 1.5; screencapture -x "$HOME/takes/row/hero-chosen.png") &
capture=$!
"$HOME/desk/row-film" row/hero 12 down:cmd tap:tab wait:1 tap:tab wait:0.8 tap:tab wait:1 tap:a wait:0.7 tap:right wait:1 up:cmd wait:2
wait "$capture"
sleep 1
$W list-workspaces --focused > "$HOME/takes/row/hero-workspace.txt"
$W list-windows --focused > "$HOME/takes/row/hero-focus.txt"
$W list-windows --all > "$HOME/takes/row/hero-inventory.txt"
screencapture -x "$HOME/takes/row/hero-result.png"
