#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=${1:-$HOME/takes/close-tab-stationary}
mkdir -p "$out"
[[ -x ~/close-tab-tools/stationary-clicks ]] || swiftc ~/close-tab-tools/stationary-clicks.swift -o ~/close-tab-tools/stationary-clicks
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/three-before.txt"
$W list-windows --focused --format '%{window-id}' > "$out/three-focus-before.txt"
cliclick m:495,60
sleep 1
screencapture -x "$out/three-hover.png"
screencapture -x -v -V 9 "$out/three-stationary.mov" > "$out/three-recorder.log" 2>&1 &
recorder=$!
sleep 1
~/close-tab-tools/stationary-clicks 495 60 3 0.6 > "$out/three-input.log"
sleep 2
screencapture -x "$out/three-held.png"
~/close-tab-tools/ui $(pgrep -x WinMuxApp) > "$out/three-held-ui.txt"
cliclick m:1240,714
sleep 1
screencapture -x "$out/three-widened.png"
wait "$recorder"
sleep 2
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/three-after.txt"
$W list-windows --focused --format '%{window-id}' > "$out/three-focus-after.txt"
before=$(wc -l < "$out/three-before.txt")
after=$(wc -l < "$out/three-after.txt")
[[ $((before - after)) == 3 ]] || { print -u2 "FAIL: three clicks removed $((before - after)) windows"; exit 1; }
[[ $(awk -F'|' '$4=="1" {n++} END {print n+0}' "$out/three-after.txt") == 2 ]] || { print -u2 'FAIL: expected two tabs left on workspace 1'; exit 1; }
cmp "$out/three-focus-before.txt" "$out/three-focus-after.txt"
print 'PASS: three stationary clicks removed three windows, left two tabs, and preserved focus'
