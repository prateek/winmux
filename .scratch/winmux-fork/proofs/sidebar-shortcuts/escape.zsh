#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
for label in base head; do
  root=$HOME/winmux
  [[ $label != base ]] || root=$HOME/winmux-base
  out=$HOME/takes/117/$label
  pkill -x WinMuxApp || true
  sleep 2
  cliclick m:1240,714
  export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
  export WINMUX_NICKEL_HELPER=$root/nickel-helper/target/release/winmux-nickel
  nohup "$root/.build/debug/WinMuxApp" > "$out/escape-app.log" 2>&1 &
  sleep 10
  W=$root/.build/debug/winmux
  $W workspace 1 >/dev/null
  wid=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
  $W focus --window-id "$wid"
  sleep 2
  cliclick m:2,360
  sleep 2
  ~/desk/keys 0 "$out/escape-query-keys.json" tap:g tap:h tap:o
  sleep 1
  screencapture -x "$out/escape-query-before.png"
  ~/desk/keys 0 "$out/escape-cancel-keys.json" tap:escape
  cliclick m:1240,714
  sleep 2
  screencapture -x "$out/escape-query-after.png"
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'
  $W list-windows --focused
done
