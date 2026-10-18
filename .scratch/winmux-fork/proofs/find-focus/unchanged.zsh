#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
tree=$1
label=$2
W=$tree/.build/debug/winmux
OUT=$HOME/takes/find-focus
pkill -x WinMuxApp || true
sleep 3
cd "$tree"
nohup env XDG_CONFIG_HOME=$HOME/demo/find-focus-config XDG_STATE_HOME=$HOME/demo/compare-$label WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel .build/debug/WinMuxApp > "$OUT/$label.app.log" 2>&1 &
sleep 15
inventory=$($W list-windows --all --format '%{window-id}|%{app-name}|%{workspace}')
id() { print -r -- "$inventory" | awk -F'|' -v app="$1" '$2==app {print $1}'; }
for app in Safari Notes; do
  workspace=$(print -r -- "$inventory" | awk -F'|' -v app="$app" '$2==app {print $3}')
  if [[ "$workspace" != 2 ]]; then $W move-node-to-workspace --window-id $(id "$app") 2; fi
done
$W focus --window-id $(id Zed)
sleep 2
{
  $W mode window
  $W trigger-binding --mode window h
  $W list-windows --focused --format '%{app-name}|%{window-title}'
  $W trigger-binding --mode window l
  $W list-windows --focused --format '%{app-name}|%{window-title}'
  $W list-modes --current
  $W trigger-binding --mode window esc
  $W list-modes --current
  $W layout floating
  $W list-windows --focused --format '%{app-name}|%{window-title}'
  $W layout tiling
  $W fullscreen on
  $W fullscreen off
  $W enable off
  $W enable on
  sleep 2
  $W list-windows --focused --format '%{app-name}|%{window-title}'
  $W list-windows --all --format '%{app-name}|%{window-title}|%{workspace}' | sort
} > "$OUT/$label.unchanged.txt" 2>&1
screencapture -x "$OUT/$label.unchanged.png"
pkill -x WinMuxApp
sleep 3
