#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euo pipefail
tree="$HOME/$1"
label=$2
source_id=${3:-49}
target_id=${4:-44}
pkill -x WinMuxApp || true
sleep 3
cp "$HOME/column-drop/off.ncl" "$HOME/demo/config/winmux/winmux.ncl"
nohup env XDG_CONFIG_HOME="$HOME/demo/config" XDG_STATE_HOME="$HOME/demo/state" \
    WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel" \
    "$tree/.build/debug/WinMuxApp" > "$HOME/takes/129/$label.log" 2>&1 < /dev/null &
sleep 20
cli="$tree/.build/debug/winmux"
"$cli" workspace 1
"$cli" move-node-to-workspace 1 --window-id "$target_id"
"$cli" move-node-to-workspace 1 --window-id "$source_id"
"$cli" layout tiling --window-id "$target_id" || true
"$cli" layout tiling --window-id "$source_id" || true
"$cli" layout h_tiles --window-id "$source_id" || true
"$cli" balance-sizes
"$cli" focus --window-id "$source_id"
sleep 3
"$cli" list-windows --all --format '%{app-name} %{window-parent-container-layout}' --json > "$HOME/takes/129/$label-before.json"
"$HOME/column-drop/frames" > "$HOME/takes/129/$label-before.frames.json"
screencapture -x "$HOME/takes/129/$label-before.png"
