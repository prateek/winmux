#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
name=$1
tree=$2
export WINMUX_CLI=$tree/.build/debug/winmux
zed=$(awk -F '|' '$2 == "Zed" { print $1; exit }' "$HOME/takes/sidebar-tree/original.windows.txt")
updater=$(awk -F '|' '$2 == "Updater" { print $1; exit }' "$HOME/takes/sidebar-tree/original.windows.txt")
pkill -x WinMuxApp || true
sleep 3
cd "$tree"
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel
nohup .build/debug/WinMuxApp > "$HOME/demo/$name.log" 2>&1 &
sleep 15
python3 ~/sidebar-tree-proof/reset-desk.py
$WINMUX_CLI layout vertical --window-id "$zed"
sleep 5
python3 ~/sidebar-arrange-proof/live.py snapshot "$name-layout-vertical"
$WINMUX_CLI layout horizontal --window-id "$zed"
sleep 5
python3 ~/sidebar-tree-proof/reset-desk.py
$WINMUX_CLI move-node-to-workspace --window-id "$updater" 4
/opt/homebrew/bin/cliclick m:8,100 w:1500
python3 ~/sidebar-arrange-proof/live.py click "$name-pin" 'Pin sidebar'
python3 ~/sidebar-arrange-proof/live.py snapshot "$name-before"
python3 ~/sidebar-arrange-proof/live.py drag "$name-plain" desk 'winmux.ncl — winmux.ncl' before 1 0
