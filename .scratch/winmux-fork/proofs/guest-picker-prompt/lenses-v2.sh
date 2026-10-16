#!/bin/bash
set -eu
out=$1
minutes=$2
mkdir -p "$out"
echo $$ > "$out/lenses.pid"
W=$HOME/winmux/.build/debug/winmux
export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
app_pid=$(pgrep -x WinMuxApp)
[ -n "$app_pid" ]
echo "process=$app_pid" >> "$out/lenses.log"
start=$(date +%s)
for i in $(seq 1 "$minutes"); do
 [ "$(pgrep -x WinMuxApp)" = "$app_pid" ]
 date -u +%FT%TZ >> "$out/lenses.log"
 echo "opening=$i elapsed=$(($(date +%s)-start))" >> "$out/lenses.log"
 "$W" lens recent --presentation strip >> "$out/lenses.log" 2>&1
 sleep 4
 "$W" debug-lens-trace --last 1 >> "$out/lenses.log" 2>&1
 "$W" debug-lens-trace --last 1 | grep -q 'active=true'
 if [ "$i" -eq 1 ] || [ "$i" -eq "$minutes" ]; then screencapture -x "$out/lens-$i.png"; fi
 "$W" lens recent --presentation strip >> "$out/lenses.log" 2>&1
 "$W" debug-lens-trace --last 1 >> "$out/lenses.log" 2>&1
 "$W" debug-lens-trace --last 1 | grep -q 'active=false'
 delay=$((start + i*60 - $(date +%s)))
 [ "$delay" -le 0 ] || sleep "$delay"
done
ps -p "$app_pid" -o pid=,etime=,lstart=,command= > "$out/process-end.txt"
"$W" list-workspaces --focused > "$out/workspace.txt"
"$W" list-windows --focused > "$out/focus.txt"
"$W" list-windows --all > "$out/windows.txt"
screencapture -x "$out/final-lenses.png"
date -u +%FT%TZ >> "$out/lenses.log"
echo DONE >> "$out/lenses.log"
