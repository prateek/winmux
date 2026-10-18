#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
K="$HOME/desk/keys"
out="$HOME/takes/row"
readback() {
  sleep 2
  $W list-workspaces --focused > "$out/$1-workspace.txt"
  $W list-windows --focused > "$out/$1-focus.txt"
  screencapture -x "$out/$1-result.png"
}
$W focus --window-id 168
sleep 2
"$HOME/desk/row-film" row/no-choice 6 down:cmd tap:tab wait:1 up:cmd wait:2
readback no-choice
$W focus --window-id 168
sleep 2
"$HOME/desk/row-film" row/escape 6 down:cmd tap:tab wait:1 tap:a wait:0.3 tap:escape wait:0.3 up:cmd wait:1
readback escape

$W focus --window-id 168
sleep 2
cliclick m:1870,1040
(sleep 2.7; cliclick c:700,360; sleep 0.4; screencapture -x "$out/click-after.png"; "$HOME/row-prototype/dock-probe" > "$out/click-tree.txt") &
click=$!
"$HOME/desk/row-film" row/click 7 down:cmd tap:tab wait:3 up:cmd wait:1
wait "$click"
readback click

$W focus --window-id 168
sleep 2
cliclick m:960,850
(sleep 2.7; cliclick m:960,570 w:300 m:960,365; sleep 0.3; screencapture -x "$out/pointer-above.png") &
pointer=$!
"$HOME/desk/row-film" row/pointer 7 down:cmd tap:tab wait:3 tap:escape up:cmd wait:1
wait "$pointer"
readback pointer

killall Dock
sleep 3
"$HOME/desk/row-film" row/dock-idle-restart 6 down:cmd tap:tab wait:1 tap:escape up:cmd wait:1
readback dock-idle-restart
(sleep 2.7; killall Dock) &
restart=$!
"$HOME/desk/row-film" row/dock-held-restart 8 down:cmd tap:tab wait:2.8 up:cmd wait:1 down:cmd tap:tab wait:1 tap:escape up:cmd
wait "$restart"
readback dock-held-restart
$W doctor > "$out/faults-doctor.txt"
