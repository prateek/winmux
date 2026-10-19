#!/bin/zsh
export TART_HOME="${TART_HOME:?Set TART_HOME in the calling shell}"
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
reset() { python3 ~/sidebar-tree-proof/reset-desk.py; }
swiftc ~/peek-proof/window-frame.swift -o ~/sidebar-tree-proof/window-frame
swiftc ~/sidebar-tree-proof/scroll.swift -o ~/sidebar-tree-proof/scroll
ghost=$(awk -F '|' '$2 == "Ghostty" { n++; if (n == 2) print $1 }' ~/takes/sidebar-tree/original.windows.txt)
$W workspace 1
$W layout floating --window-id "$ghost"
$W focus --window-id "$ghost"
sleep 3
~/sidebar-tree-proof/window-frame "$ghost" 700 400 500 320
sleep 3
live snapshot size-remembered
live draglabel size-tiled desk 'winmux.ncl — winmux.ncl' after 1 0
live draglabel size-restored desk 'A dialog that is not yours' before 0 0
reset
cp ~/sidebar-tree-proof/configs/both-short.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
cliclick m:180,700 w:500
~/sidebar-tree-proof/scroll -450
sleep 2
live snapshot scrolled-header
live clicklabel scrolled-unpin 'Unpin sidebar'
live clicklabel scrolled-repin 'Pin sidebar'
cliclick m:180,700 w:500
~/sidebar-tree-proof/scroll -2000
sleep 2
live snapshot scrolled-bottom
live draglabel scrolled-new-workspace Calculator 'New Workspace' center
reset
cp ~/sidebar-tree-proof/configs/both-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
cliclick m:180,500 w:500
~/sidebar-tree-proof/scroll 2000
sleep 2
live snapshot pass2-final-restored
