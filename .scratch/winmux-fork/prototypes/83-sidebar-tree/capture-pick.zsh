#!/bin/zsh
# Guest-only Safari take, with the page already at ?view=pick&theme=light and pinned.
export TART_HOME
set -eu
: "${TART_HOME:?Set TART_HOME in the vm ssh shell}"
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/sidebar-tree/pick
capture() { screencapture -x "$out/$1.png"; "$HOME/sidebar-tree/read-page" > "$out/$1.txt"; }
reset() { cliclick c:727,114 w:300; }
take_drag() {
  local name=$1
  shift
  "$HOME/sidebar-tree/drag" "$@" &
  local drag_pid=$!
  sleep 1.9
  screencapture -x "$out/$name-target.png"
  wait "$drag_pid"
  cliclick m:1800,900 w:400
  capture "$name"
}
cliclick c:510,485 m:1800,900 w:300
capture splits-only
cliclick c:510,485 c:533,485 m:1800,900 w:300
capture columns-only
cliclick c:510,485 m:1800,900 w:300
capture both-levels
cliclick c:510,485 c:533,485 m:1800,900 w:300
take_drag sibling-before 420 513 420 375
reset
take_drag sibling-after 420 513 420 387
reset
take_drag floating-tiled 420 873 420 387
reset
take_drag refuse-self 420 537 490 537
take_drag refuse-descendant 420 537 420 585
take_drag refuse-workspace-drag 420 485 420 381
cliclick c:533,485 w:300
take_drag refuse-column-drag 420 513 420 381
cliclick c:533,485 w:300
for term in Safari Grievances qzxnomatch; do
  reset
  cliclick c:470,114 "t:$term" m:1800,900 w:400
  capture "search-$term"
done
reset
capture final-flat
take_drag refuse-workspace-drag 375 485 420 381
reset
take_drag column-sibling-flat 420 381 420 519
cliclick c:375,461 m:1800,900 w:300
capture column-sibling-sketch
cliclick c:510,461 m:1800,900 w:300
capture splits-only-after-sibling
cliclick c:510,461 c:533,461 m:1800,900 w:300
capture columns-only-after-sibling
cliclick c:510,461 m:1800,900 w:300
capture both-after-sibling
cliclick c:438,250 c:674,250 w:300
capture config-both
cliclick kd:cmd t:r ku:cmd w:800 m:238,400 w:400
capture config-reloaded-hover
cliclick c:438,250 c:674,250 w:300 c:1342,250 m:1800,900 w:300
reset
capture final-flat
