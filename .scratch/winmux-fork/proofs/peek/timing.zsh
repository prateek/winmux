#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
out=$HOME/captures/capture-times.txt
: > "$out"
for app in Safari Zed; do
  id=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' -v app="$app" '$2==app {print $1; exit}')
  $W focus --window-id "$id"
  $W fullscreen on --window-id "$id" --no-outer-gaps
  sleep 1
  ~/peek-proof/capture-times "$app:$id" >> "$out"
  $W fullscreen off --window-id "$id"
done
$W doctor > ~/captures/timing-display.txt
cat "$out"
