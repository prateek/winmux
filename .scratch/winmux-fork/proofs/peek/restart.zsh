#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
root=${1:-$HOME/winmux}
pkill -x WinMuxApp || true
sleep 1
export WINMUX_DEBUG_STRIP_EVENTS=1
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$root/nickel-helper/target/release/winmux-nickel
cd "$root"
nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &
sleep 6
W=$root/.build/debug/winmux
$W config status
$W workspace 2 || true
$W workspace 1 || true
safari=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Safari" {print $1}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1}')
$W focus --window-id $safari
$W focus --window-id $zed
cliclick m:1278,718
