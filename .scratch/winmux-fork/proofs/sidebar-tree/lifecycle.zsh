#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
cp ~/sidebar-tree-proof/configs/both-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
$W workspace 2
sleep 4
cliclick m:8,100 w:900
python3 ~/sidebar-tree-proof/live.py clicklabel lifecycle-pinned 'Pin sidebar'
python3 ~/sidebar-tree-proof/live.py snapshot before-close
sidebar_close_id=$(awk -F '|' '$3 == "Subscription events" { print $1; exit }' ~/takes/sidebar-tree/original.windows.txt)
$W close --window-id "$sidebar_close_id"
sleep 4
python3 ~/sidebar-tree-proof/live.py snapshot after-close
cp ~/sidebar-tree-proof/configs/both-240.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
python3 ~/sidebar-tree-proof/live.py hoverlabel clipped-title-hover '@tabs:2' 0
sleep 3
python3 ~/sidebar-tree-proof/live.py snapshot clipped-title-tooltip-delayed
export WINMUX_CLI=$HOME/sidebar-tree-proof/quiet-cli
zsh ~/desk/stage-rich.sh
unset WINMUX_CLI
killall UserNotificationCenter 2>/dev/null || true
sleep 4
python3 ~/sidebar-tree-proof/live.py snapshot final-native
