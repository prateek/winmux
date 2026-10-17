#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
label=$1
root=$2
W=$root/.build/debug/winmux
out=$HOME/takes/117/$label
mkdir -p "$out"
for mode in always auto-hide; do
  pkill -x WinMuxApp || true
  sleep 2
  cliclick m:1240,714 ku:fn
  export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
  export WINMUX_NICKEL_HELPER=$root/nickel-helper/target/release/winmux-nickel
  nohup "$root/.build/debug/WinMuxApp" --config-path "$HOME/desk/$mode.ncl" > "$out/$mode-app.log" 2>&1 &
  sleep 10
  $W config status
  screencapture -x "$out/$mode-resting.png"
  $W workspace 1 >/dev/null
  wid=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
  $W focus --window-id "$wid"
  sleep 2
  cliclick m:2,360
  sleep 2
  ~/desk/keys "$(date +%s)" "$out/$mode-keys.json" tap:g tap:h tap:o
  sleep 1
  screencapture -x "$out/$mode-search.png"
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'
  cliclick kd:ctrl kp:arrow-up ku:ctrl
  sleep 1
  screencapture -x "$out/$mode-control-up.png"
  cliclick m:1240,714
  sleep 2
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'
  $W list-windows --focused
  pkill -x WinMuxApp
  sleep 2
  cliclick kp:esc
  sleep 2
done
