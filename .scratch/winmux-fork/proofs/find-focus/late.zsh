#!/bin/zsh
set -eu
source "$HOME/focus-proof/live.zsh" functions
$W mode main
$W focus --window-id "$zed"
sleep 2
take fade-restart late-restart
readback mission-control.before
screencapture -x -v -V 5 "$OUT/mission-control.mov" > "$OUT/mission-control.recorder.txt" 2>&1 &
recorder=$!
sleep 0.7
$W find-focus
sleep 0.15
screencapture -x "$OUT/mission-control.mark.png"
"/System/Applications/Mission Control.app/Contents/MacOS/Mission Control" 2
sleep 0.4
screencapture -x "$OUT/mission-control.open.png"
$W find-focus > "$OUT/mission-control.stdout.txt" 2> "$OUT/mission-control.stderr.txt"
print $? > "$OUT/mission-control.exit.txt"
sleep 0.15
screencapture -x "$OUT/mission-control.suppressed.png"
$HOME/focus-proof/arrow-chord down
sleep 2
readback mission-control.after
screencapture -x "$OUT/mission-control.end.png"
wait "$recorder"
