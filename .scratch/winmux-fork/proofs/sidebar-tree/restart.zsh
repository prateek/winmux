#!/bin/zsh
set -eu
name=$1
tree=${2:-$HOME/winmux}
pkill -x WinMuxApp || true
sleep 3
cd "$tree"
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel
nohup .build/debug/WinMuxApp > "$HOME/demo/$name.log" 2>&1 &
sleep 12
if [[ ${3:-pin} == pin ]]; then
    /opt/homebrew/bin/cliclick m:8,100 w:900
    python3 ~/sidebar-tree-proof/live.py clicklabel "$name" 'Pin sidebar'
fi
