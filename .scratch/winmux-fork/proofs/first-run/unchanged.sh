#!/bin/bash
# The same already-granted startup and command script runs against base and feature.
set -euo pipefail
root=${1:?source tree}
label=${2:?base or feature}
export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/demo/unchanged-$label"
export WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel"
mkdir -p "$XDG_STATE_HOME" "$HOME/takes/first-run"
pkill -x WinMuxApp || true
sleep 3
"$HOME/demo/frames" > "$HOME/takes/first-run/$label.before.frames.json"
nohup "$root/.build/debug/WinMuxApp" > "$HOME/demo/$label.log" 2>&1 &
sleep 22
W="$root/.build/debug/winmux"
{
  echo '$ winmux list-windows --all --format ...'
  "$W" list-windows --all --format '%{app-name}|%{window-title}|%{workspace}'
  echo '$ winmux list-workspaces --focused'
  "$W" list-workspaces --focused
  echo '$ winmux workspace 2; winmux workspace 1'
  "$W" workspace 2
  sleep 2
  "$W" workspace 1
  sleep 3
  "$W" doctor
} > "$HOME/takes/first-run/$label.cli.txt" 2>&1
"$HOME/demo/frames" > "$HOME/takes/first-run/$label.tiled.frames.json"
screencapture -x "$HOME/takes/first-run/$label.tiled.png"
pkill -x WinMuxApp
sleep 4
"$HOME/demo/frames" > "$HOME/takes/first-run/$label.quit.frames.json"
diff -u "$HOME/takes/first-run/$label.before.frames.json" "$HOME/takes/first-run/$label.quit.frames.json"
