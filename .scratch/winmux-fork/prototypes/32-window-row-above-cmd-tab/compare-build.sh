#!/bin/bash
set -euo pipefail
tree=$1
label=$2
out="$HOME/takes/row"
pkill -x WinMuxApp || true
sleep 3
cd "$tree"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/demo/state"
export WINMUX_NICKEL_HELPER="$tree/nickel-helper/target/release/winmux-nickel"
nohup "$tree/.build/debug/WinMuxApp" > "$out/$label-app.log" 2>&1 < /dev/null &
sleep 20
W="$tree/.build/debug/winmux"
$W doctor > "$out/$label-doctor.txt"
$W list-windows --all --format '%{window-id}|%{app-name}|%{app-pid}|%{app-bundle-id}|%{window-title}|%{workspace}' > "$out/$label-inventory.txt"
"$HOME/desk/keys" 0 "$out/$label-system.events.json" down:cmd tap:tab wait:1.5 tap:escape up:cmd
sleep 2
$W list-windows --focused > "$out/$label-focus.txt"
screencapture -x "$out/$label-desktop.png"
