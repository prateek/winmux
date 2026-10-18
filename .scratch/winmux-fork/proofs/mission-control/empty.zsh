#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
cd ~/winmux
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
out=$HOME/takes/mission-control/branch
nohup .build/debug/WinMuxApp > "$out/empty-outline-app.log" 2>&1 &
sleep 25
W=$HOME/winmux/.build/debug/winmux
$W workspace 2
sleep 3
$W column-count 4
$W focus-column 4
sleep 3
~/mission-control/parking save "$out/empty-outline-frames.json"
screencapture -x "$out/empty-outline.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control-empty-outline.png"
~/mission-control/parking ax > "$out/mission-control-empty-outline-ax.txt"
cliclick kp:esc ku:fn
sleep 2
$W column-count 3
$W reload-config
$W focus --window-id 192
sleep 3
$W list-windows --all --json > "$out/final-windows.json"
$W list-workspaces --focused > "$out/final-workspace.txt"
$W list-columns > "$out/final-columns.txt"
screencapture -x "$out/final-desktop.png"
pkill -x WinMuxApp
sleep 3
