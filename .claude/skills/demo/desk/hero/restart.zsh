#!/bin/zsh
# A restart alone can renumber the sidebar, so restart by restaging: stage-desk.sh
# stops WinMux, starts it again and restores 1 above 2 and the MRU order.
set -eu
export PATH=/opt/homebrew/bin:$PATH
~/desk/stage-desk.sh
cliclick ku:fn m:1240,714
sleep 2
$HOME/winmux/.build/debug/winmux debug-lens-trace --last 1
