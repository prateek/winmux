#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
label=${1:?base or head}
root=${2:?source tree}
config=${3:?configuration directory}
out="$HOME/takes/modes/$label"
mkdir -p "$out" "$HOME/demo/modes-$label-state"
W="$root/.build/debug/winmux"
export WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel"
pkill -x WinMuxApp || true
sleep 3
nohup env XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$HOME/demo/modes-$label-state" WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel" "$root/.build/debug/WinMuxApp" > "$out/manager.log" 2>&1 &
sleep 15
cliclick m:1240,714
"$W" config check "$config/winmux/winmux.ncl" > "$out/config-check.txt" 2>&1
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/initial-windows.txt"
window_id() { awk -F'|' -v app="$1" '$2 == app { print $1; exit }' "$out/initial-windows.txt"; }
"$W" focus --window-id "$(window_id Zed)"
"$W" move left || true
"$W" focus --window-id "$(window_id Safari)"
"$W" move left || true
for app in Notes Safari Ghostty Zed; do "$W" focus --window-id "$(window_id "$app")"; sleep 0.8; done
D="$HOME/modes/drive"
"$D" "$root" "$out" snapshot:desk \
  down:cmd tap:tab wait:1 snapshot:cmd-tab-first \
  tap:tab wait:1 snapshot:cmd-tab-next \
  down:shift tap:tab wait:1 snapshot:cmd-tab-back up:shift up:cmd wait:1 snapshot:cmd-tab-release \
  down:cmd down:shift tap:tab wait:1 snapshot:reverse-first \
  tap:tab wait:1 snapshot:reverse-next up:shift up:cmd wait:1 snapshot:reverse-release \
  down:alt tap:slash wait:1 snapshot:search-held tap:tab wait:1 snapshot:search-stepped \
  tap:z wait:1 snapshot:search-typed up:alt tap:escape wait:1 snapshot:search-browse \
  tap:escape wait:1 snapshot:search-closed \
  down:alt down:shift tap:o wait:1 snapshot:overview-held up:shift up:alt wait:1 snapshot:overview-browse \
  tap:h wait:1 snapshot:overview-h tap:j wait:1 snapshot:overview-j \
  tap:k wait:1 snapshot:overview-k tap:l wait:1 snapshot:overview-l \
  tap:escape wait:1 snapshot:overview-closed
"$W" list-windows --all --search z --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/search-z-matches.txt"
"$W" focus --window-id "$(window_id Zed)"
sleep 2
"$D" "$root" "$out" down:cmd tap:tab wait:1 snapshot:close-selected \
  tap:w wait:3 snapshot:close-removed up:cmd wait:2 snapshot:close-release
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/final-windows.txt"
pkill -x WinMuxApp || true
sleep 3
