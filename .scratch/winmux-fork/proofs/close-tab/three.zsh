#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/close-tab
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/three-before.txt"
cliclick m:495,60
sleep 1
rm -f "$out/three-closes.mov"
screencapture -x -k -v -V 8 "$out/three-closes.mov" > "$out/recorder.log" 2>&1 &
recorder=$!
sleep 1.5
cliclick c:495,60 w:400 c:495,60 w:400 c:495,60 w:1000
screencapture -x "$out/three-held.png"
~/close-tab-tools/ui $(pgrep -x WinMuxApp) > "$out/three-held-ui.txt"
cliclick m:1240,714
sleep 1
screencapture -x "$out/three-widened.png"
~/close-tab-tools/ui $(pgrep -x WinMuxApp) > "$out/three-widened-ui.txt"
wait "$recorder"
sleep 2
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/three-after.txt"
$W list-windows --focused --format '%{window-id}' > "$out/three-focused.txt"
