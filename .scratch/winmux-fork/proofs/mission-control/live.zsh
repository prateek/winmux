#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
label=$1
root=$2
out=$HOME/takes/mission-control/$label
mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 3
cd "$root"
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
nohup "$root/.build/debug/WinMuxApp" > "$out/app.log" 2>&1 &
sleep 25
W=$root/.build/debug/winmux
$W doctor > "$out/doctor.txt"
for n in 1 2 3 4; do
    $W workspace "$n"
    sleep 3
done
$W workspace 2
sleep 5
cliclick m:1880,1070
$W list-windows --all --json > "$out/windows-start.json"
$W list-columns > "$out/columns-start.txt"
~/mission-control/parking save "$out/frames.json"
screencapture -x "$out/desktop.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control.png"
~/mission-control/parking ax > "$out/mission-control-ax.txt"
~/mission-control/arrow-chord up
cliclick ku:fn
sleep 2
cliclick m:5,500
sleep 2
screencapture -x "$out/sidebar-expanded.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control-expanded.png"
~/mission-control/parking ax > "$out/mission-control-expanded-ax.txt"
~/mission-control/arrow-chord up
cliclick ku:fn m:1880,1070
sleep 2
$W mode window
sleep 1
screencapture -x "$out/hud.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control-hud.png"
~/mission-control/parking ax > "$out/mission-control-hud-ax.txt"
~/mission-control/arrow-chord up
cliclick ku:fn
sleep 2
$W mode main
$W lens windows
sleep 3
screencapture -x "$out/lens.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/mission-control-lens.png"
~/mission-control/parking ax > "$out/mission-control-lens-ax.txt"
~/mission-control/arrow-chord up
cliclick ku:fn
sleep 2
$W lens windows
sleep 2
$W workspace 3
sleep 3
$W workspace 2
sleep 3
screencapture -x "$out/returned.png"
$W list-workspaces --focused > "$out/workspace-end.txt"
$W list-windows --focused --json > "$out/focus-end.json"
$W list-windows --all --json > "$out/windows-end.json"
$W debug-lens-trace --last 2 > "$out/lens-trace.txt"
