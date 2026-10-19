#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
sidebar_notes_id=$(awk -F '|' '$2 == "Notes" { print $1; exit }' "$HOME/takes/sidebar-tree/original.windows.txt")
for variant in base feature; do
    [[ $variant == base ]] && tree=$HOME/sidebar-base || tree=$HOME/winmux
    export WINMUX_CLI=$tree/.build/debug/winmux
    cp ~/desk/rich/winmux.ncl ~/.config/winmux/winmux.ncl
    zsh ~/sidebar-tree-proof/restart.zsh "$variant-unchanged" "$tree" no-pin
    zsh ~/sidebar-tree-proof/unchanged.zsh "$WINMUX_CLI" "$HOME/takes/sidebar-tree/$variant-unchanged"
    python3 ~/sidebar-tree-proof/live.py snapshot "$variant-unchanged-end"
    cliclick m:8,100 w:900
    python3 ~/sidebar-tree-proof/live.py draglabel "$variant-sidebar-workspace" Calculator 'Workspace 1' center
    python3 ~/sidebar-tree-proof/reset-desk.py
    "$tree/nickel-helper/target/release/winmux-nickel" check ~/sidebar-tree-proof/configs/native-hook-common.ncl
    cp ~/sidebar-tree-proof/configs/native-hook-common.ncl ~/.config/winmux/winmux.ncl
    "$WINMUX_CLI" reload-config
    "$WINMUX_CLI" workspace 2
    sleep 4
    "$WINMUX_CLI" place --dry-run --json --window-id "$sidebar_notes_id" > "$HOME/takes/sidebar-tree/$variant-hook-preview.json"
    "$WINMUX_CLI" move-node-to-workspace --window-id "$sidebar_notes_id" 1
    "$WINMUX_CLI" move-node-to-workspace --window-id "$sidebar_notes_id" 2
    sleep 4
    python3 ~/sidebar-tree-proof/live.py snapshot "$variant-hook-end"
    python3 ~/sidebar-tree-proof/reset-desk.py
done
unset WINMUX_CLI
