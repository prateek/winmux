#!/bin/zsh
set -u
export PATH=/opt/homebrew/bin:$PATH
label=${1:-during}
root=${2:-$HOME/winmux}
out=$HOME/takes/mission-control/$label
rm -rf "$out"; mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 3
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
nohup "$root/.build/debug/WinMuxApp" > "$out/app.log" 2>&1 &
sleep 25
W=$root/.build/debug/winmux
$W doctor | head -3 > "$out/doctor.txt"
for n in 1 2 3 4; do $W workspace "$n"; sleep 3; done
$W workspace 2
sleep 5
cliclick m:1880,1070
$W list-columns > "$out/columns-start.txt"
~/mission-control/parking save "$out/frames.json"
screencapture -x "$out/0-desktop.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/1-mc.png"
$W resize width +120 > "$out/resize.txt" 2>&1
sleep 3
screencapture -x "$out/2-mc-after-resize.png"
$W balance-sizes > "$out/balance.txt" 2>&1
sleep 3
screencapture -x "$out/3-mc-after-balance.png"
$W workspace 3 > "$out/ws3.txt" 2>&1
sleep 3
screencapture -x "$out/4-mc-after-workspace3.png"
$W workspace 2 > "$out/ws2.txt" 2>&1
sleep 3
screencapture -x "$out/5-mc-after-workspace2.png"
~/mission-control/parking ax > "$out/5-ax.txt"
if ~/mission-control/parking ax | grep -q 'Optional(Mission Control)'; then
    ~/mission-control/arrow-chord up
fi
cliclick ku:fn m:1880,1070
sleep 3
screencapture -x "$out/6-desktop-end.png"
$W list-columns > "$out/columns-end.txt"
$W list-workspaces --focused > "$out/workspace-end.txt"
