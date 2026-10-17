#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
label=$1
root=${2:-$HOME/winmux}
out=$HOME/takes/117/$label
W=$root/.build/debug/winmux
keys() { ~/desk/keys "$(date +%s)" "$out/selection-keys-$(date +%s).json" "$@"; }
cliclick m:1240,714 ku:fn
$W workspace 1 >/dev/null
sleep 2
cliclick m:2,360
sleep 2
keys tap:w tap:o tap:r tap:k tap:s tap:p tap:a tap:c tap:e
sleep 1
screencapture -x "$out/selection-initial.png"
keys tap:down
sleep 1
screencapture -x "$out/selection-down.png"
keys tap:up
sleep 1
screencapture -x "$out/selection-up.png"
keys tap:return
sleep 2
$W list-workspaces --focused
$W list-windows --focused
cliclick m:1240,714
sleep 2
