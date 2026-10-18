#!/bin/zsh
set -eu
source "$HOME/focus-proof/live.zsh" functions
$W mode main
$W focus --window-id "$ghostty"
$W layout floating
sleep 2
readback close.before
screencapture -x -v -V 4 "$OUT/close.mov" > "$OUT/close.recorder.txt" 2>&1 &
recorder=$!
sleep 0.7
$W find-focus
sleep 0.15
screencapture -x "$OUT/close.mark.png"
$W close > "$OUT/close.stdout.txt" 2> "$OUT/close.stderr.txt"
print $? > "$OUT/close.exit.txt"
sleep 2
readback close.after
screencapture -x "$OUT/close.end.png"
wait "$recorder"
