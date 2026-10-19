#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
export SIDEBAR_FIXTURE=final-native
sidebar_notes_id=$(awk -F '|' '$2 == "Notes" { print $1; exit }' ~/takes/sidebar-tree/final-native.windows.txt)
for variant in base feature; do
    [[ $variant == base ]] && tree=$HOME/sidebar-base || tree=$HOME/winmux
    export WINMUX_CLI=$tree/.build/debug/winmux
    cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
    zsh ~/sidebar-tree-proof/restart.zsh "$variant-inputs" "$tree" no-pin
    killall UserNotificationCenter 2>/dev/null || true
    python3 ~/sidebar-tree-proof/reset-desk.py
    $WINMUX_CLI move-node-to-column 3 --window-id "$sidebar_notes_id"
    sleep 4
    python3 ~/sidebar-tree-proof/live.py snapshot "$variant-column-command"
    python3 ~/sidebar-tree-proof/reset-desk.py
    $WINMUX_CLI workspace 2
    sleep 4
    python3 ~/sidebar-tree-proof/live.py drag "$variant-strip-reorder" 1182 60 600 60
    python3 ~/sidebar-tree-proof/reset-desk.py
    python3 ~/sidebar-tree-proof/live.py drag "$variant-screen-drop" 300 58 1450 140
    python3 ~/sidebar-tree-proof/reset-desk.py
done
unset WINMUX_CLI SIDEBAR_FIXTURE
