#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
reset() { python3 ~/sidebar-tree-proof/reset-desk.py; }
cp ~/sidebar-tree-proof/configs/both-320.ncl ~/.config/winmux/winmux.ncl
$W reload-config
sleep 4
live snapshot levels-before-drops
live draglabel levels-before desk 'winmux.ncl — winmux.ncl' before 1 0
reset
live draglabel levels-after desk 'winmux.ncl — winmux.ncl' after 1 0
reset
live draglabel tab-after 'Notes – No notes' 'Fixed Columns' after
reset
live draglabel direct-column-before desk 'Notes – No notes' before 1 0
reset
live draglabel direct-column-after desk 'Notes – No notes' after 1 0
reset
live readback own-workspace-before
live draglabel own-workspace 'Notes – No notes' 'Workspace 2' center
live draglabel column-row desk 'Column 1 · 28%' center 1 0
reset
live dragmark column-mark desk 2 2 1
reset
live draglabel group-join '@tabs:3' '@tabs:2' center
reset
live draglabel floating-tiled Calculator 'winmux.ncl — winmux.ncl' after
reset
live draglabel floating-workspace Calculator 'Workspace 1' center
reset
live draglabel floating-window Calculator 'A dialog that is not yours' before
reset
live draglabel floating-group Calculator Floating center
reset
live draglabel group-floats '@tabs:3' 'A dialog that is not yours' after
reset
live draglabel split-target 'Notes – No notes' '↔ Horizontal tiles' center
reset
live draglabel split-source '↔ Horizontal tiles' '@tabs:2' center
reset
live readback refusals-before
live draglabel self-refusal 'Notes – No notes' 'Notes – No notes' after
live draglabel descendant-refusal '@tabs:3' 'Fixed Columns' before
live draglabel split-descendant-refusal '↔ Horizontal tiles' desk after 0 0
live draglabel workspace-heading-refusal 'Workspace 2' 'Workspace 1' center
live draglabel column-heading-refusal 'Column 1 · 28%' 'Workspace 2' center
