#!/bin/zsh
export TART_HOME="${TART_HOME:?Set TART_HOME in the calling shell}"
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
reset() { python3 ~/sidebar-tree-proof/reset-desk.py; }
cp ~/sidebar-tree-proof/configs/flat-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
live draglabel flat-before desk 'winmux.ncl — winmux.ncl' before 1 0
reset
live draglabel flat-after desk 'winmux.ncl — winmux.ncl' after 1 0
reset
cp ~/sidebar-tree-proof/configs/both-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
live draglabel levels-before desk 'winmux.ncl — winmux.ncl' before 1 0
reset
live draglabel levels-after desk 'winmux.ncl — winmux.ncl' after 1 0
reset
live draglabel direct-column-before desk 'Notes – No notes' before 1 0
reset
live draglabel direct-column-after desk 'Notes – No notes' after 1 0
reset
live draglabel group-join '@tabs:3' '@tabs:2' center
reset
live snapshot split-screen-cancel-start
live draglabelpoint split-screen-cancel '↔ Horizontal tiles' 1200 220
live snapshot split-new-workspace-cancel-start
live draglabel split-new-workspace-cancel '↔ Horizontal tiles' 'New Workspace' center
live draglabel split-source '↔ Horizontal tiles' '@tabs:2' center
reset
live draglabelpoint window-row-screen desk 1200 220 1
reset
live draglabel floating-tiled Calculator 'winmux.ncl — winmux.ncl' after
live draglabel remembered-floating Calculator 'A dialog that is not yours' before
reset
live snapshot pass2-core-finished
