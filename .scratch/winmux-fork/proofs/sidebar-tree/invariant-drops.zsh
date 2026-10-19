#!/bin/zsh
set -eu
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
reset() { python3 ~/sidebar-tree-proof/reset-desk.py; }
live draglabel leave-empty-column 'Notes – No notes' '@tabs:2' center
live draglabel invariant-empty-workspace desk 'Workspace 2' center 1 0
reset
live draglabel invariant-occupied-workspace desk 'Workspace 2' center 1 0
reset
live draglabel invariant-group-workspace '@tabs:3' 'Workspace 3' center
reset
