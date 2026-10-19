#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
out="$HOME/takes/tab-strip"
cli="$HOME/winmux/.build/debug/winmux"
swiftc "$HOME/tab-strip-tools/icons.swift" -o "$HOME/tab-strip-tools/icons"
"$HOME/tab-strip-tools/icons"
for pair in chrome:201 code:227 ghostty:248; do
  app=${pair%:*}; id=${pair#*:}
  "$cli" focus --window-id "$id"
  cliclick m:1860,1072
  sleep 4
  screencapture -x "$out/today-$app-rest.png"
  cliclick m:650,60
  sleep 1
  screencapture -x "$out/today-$app-tab-hover.png"
  cliclick m:1888,60
  sleep 1
  screencapture -x "$out/today-$app-grip-hover.png"
  cliclick m:1860,1072
  "$HOME/tab-strip-tools/keys" 0 "$out/$app-hold.events.json" down:alt wait:1.0 up:alt &
  keypid=$!
  sleep .7
  screencapture -x "$out/today-$app-hints.png"
  wait "$keypid"
  "$cli" list-windows --all --json > "$out/after-$app.json"
done
"$cli" focus --window-id 201
cliclick m:1860,1072
sleep 3
screencapture -x "$out/sidebar-collapsed.png"
cliclick m:2,180
sleep 2
screencapture -x "$out/sidebar-expanded.png"
cliclick m:1860,1072
sleep 2
"$cli" agent query > "$out/baseline-tree.json"
