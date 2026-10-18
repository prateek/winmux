#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
label=$1
W=$2/.build/debug/winmux
out=$HOME/takes/mission-control/$label
$W workspace 2
sleep 3
$W focus --window-id 192
sleep 2
cliclick m:1880,1070
screencapture -x -v -V 24 "$out/interaction.mov" &
recorder=$!
sleep 2
cliclick c:920,60
sleep 2
$W list-windows --focused --json > "$out/tab-click.json"
screencapture -x "$out/tab-click.png"
cliclick c:1180,60
sleep 2
$W list-columns > "$out/divider-before.txt"
cliclick dd:1390,500 dm:1430,500 du:1430,500
sleep 2
$W list-columns > "$out/divider-after.txt"
screencapture -x "$out/divider-after.png"
cliclick dd:1430,500 dm:1390,500 du:1390,500
sleep 2
cliclick m:5,500
sleep 2
cliclick c:100,440
sleep 2
$W list-workspaces --focused > "$out/sidebar-click.txt"
screencapture -x "$out/sidebar-click.png"
$W workspace 2
sleep 3
cliclick m:1880,1070
screencapture -x "$out/interaction-end.png"
$W list-windows --all --json > "$out/interaction-windows-end.json"
$W list-columns > "$out/interaction-columns-end.txt"
wait "$recorder"
