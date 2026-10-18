#!/bin/zsh
set -eu
source "$HOME/focus-proof/live.zsh" functions
$W mode main
$W focus --window-id "$zed"
set_layout h_tab_group
$W focus --tab-index 1
sleep 2
readback tab-active.previous
$W focus tab-next
sleep 2
take tab-active
$W debug-windows --window-id "$zed" > "$OUT/tab-active.debug.txt"
set_layout h_tiles
sleep 2
readback resize.before
screencapture -x -v -V 4 "$OUT/resize.mov" > "$OUT/resize.recorder.txt" 2>&1 &
recorder=$!
sleep 0.7
$W find-focus
sleep 0.15
screencapture -x "$OUT/resize.mark.png"
$W resize width +100
sleep 0.15
screencapture -x "$OUT/resize.after-action.png"
sleep 1.5
readback resize.after
wait "$recorder"
$W balance-sizes
sleep 1
$W enable off
$W find-focus > "$OUT/disabled.stdout.txt" 2> "$OUT/disabled.stderr.txt"
print $? > "$OUT/disabled.exit.txt"
screencapture -x "$OUT/disabled.png"
$W enable on
