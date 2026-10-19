#!/bin/zsh
set -eu
W=$HOME/winmux/.build/debug/winmux
live() { python3 ~/sidebar-tree-proof/live.py "$@"; }
load() {
    cp "$HOME/sidebar-tree-proof/configs/$1.ncl" ~/.config/winmux/winmux.ncl
    $W reload-config
    sleep 4
    live snapshot "$2"
    $W config status > "$HOME/takes/sidebar-tree/$2.config-status.txt"
}
load flat-320 defaults-flat
live clicklabel override-splits-2 'Show splits' 1
live clicklabel override-both-2 'Show Columns' 0
load flat-320 defaults-unchanged-reload
load splits-320 defaults-only-splits-changed
load both-320 defaults-both-reload
zsh ~/sidebar-tree-proof/restart.zsh defaults-both-restart
load columns-320 defaults-columns-reload
zsh ~/sidebar-tree-proof/restart.zsh defaults-columns-restart
load splits-320 defaults-splits-reload
zsh ~/sidebar-tree-proof/restart.zsh defaults-splits-restart
live clicklabel override-splits-off-2 'Show splits' 1
load both-320 defaults-only-columns-changed
live clicklabel override-splits-back-on-2 'Show splits' 1
zsh ~/sidebar-tree-proof/restart.zsh defaults-final-both
