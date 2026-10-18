#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/mission-control/late
mkdir -p "$out"
$W mode main
~/mission-control/parking save "$out/frames.json"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/before.png"
$W mode window
sleep 2
screencapture -x "$out/hud-opened-during-mission-control.png"
~/mission-control/parking ax > "$out/hud-ax.txt"
$W mode main
$W lens windows
sleep 3
screencapture -x "$out/lens-opened-during-mission-control.png"
~/mission-control/parking ax > "$out/lens-ax.txt"
$W lens windows
sleep 2
if ~/mission-control/parking ax | grep -q 'Optional(Mission Control)'; then
    ~/mission-control/arrow-chord up
fi
cliclick ku:fn m:1880,1070
sleep 3
$W list-workspaces --focused > "$out/workspace-end.txt"
$W list-windows --all --json > "$out/windows-end.json"
$W debug-lens-trace --last 2 > "$out/lens-trace.txt"
screencapture -x "$out/desktop-end.png"
