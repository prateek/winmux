#!/bin/bash
set -u
out=$1
minutes=$2
mkdir -p "$out"
W=$HOME/winmux/.build/debug/winmux
export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
start=$(date +%s)
for i in $(seq 1 "$minutes"); do
 date -u +%FT%TZ >> "$out/lenses.log"
 echo "opening=$i elapsed=$(($(date +%s)-start))" >> "$out/lenses.log"
 "$W" lens recent --presentation strip >> "$out/lenses.log" 2>&1
 echo "open-status=$?" >> "$out/lenses.log"
 sleep 4
 "$W" debug-lens-trace --last 1 >> "$out/lenses.log" 2>&1
 /opt/homebrew/bin/cliclick kp:escape w:300 >> "$out/lenses.log" 2>&1
 "$W" debug-lens-trace --last 1 >> "$out/lenses.log" 2>&1
 delay=$((start + i*60 - $(date +%s)))
 [ "$delay" -le 0 ] || sleep "$delay"
done
"$W" list-workspaces --focused > "$out/workspace.txt"
"$W" list-windows --focused > "$out/focus.txt"
"$W" list-windows --all > "$out/windows.txt"
screencapture -x "$out/final-lenses.png"
date -u +%FT%TZ >> "$out/lenses.log"
echo DONE >> "$out/lenses.log"
