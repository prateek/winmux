#!/bin/zsh
export TART_HOME="${TART_HOME:?Set TART_HOME in the calling shell}"
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
swiftc ~/sidebar-tree-proof/frames.swift -o ~/sidebar-tree-proof/frames
ghost=$(awk -F '|' '$2 == "Ghostty" { n++; if (n == 2) print $1 }' ~/takes/sidebar-tree/original.windows.txt)
$W workspace 1
$W layout floating --window-id "$ghost"
$W focus --window-id "$ghost"
sleep 3
~/sidebar-tree-proof/window-frame "$ghost" 700 400 500 320
sleep 3
live snapshot native-size-remembered
~/sidebar-tree-proof/frames > ~/takes/sidebar-tree/native-size-remembered.frames.json
live draglabel native-size-tiled desk 'winmux.ncl — winmux.ncl' after 1 0
~/sidebar-tree-proof/frames > ~/takes/sidebar-tree/native-size-tiled.frames.json
live draglabel native-size-restored desk 'A dialog that is not yours' before 0 0
~/sidebar-tree-proof/frames > ~/takes/sidebar-tree/native-size-restored.frames.json
python3 ~/sidebar-tree-proof/reset-desk.py
live snapshot pass2-final-restored
~/sidebar-tree-proof/frames > ~/takes/sidebar-tree/pass2-final-restored.frames.json
