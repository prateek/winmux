#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
root="$HOME/winmux"
W="$root/.build/debug/winmux"
D="$HOME/modes/drive"
out="$HOME/takes/modes/${1:-verbs-final}"
mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 3
nohup env XDG_CONFIG_HOME="$HOME/demo/modes-advanced-config" XDG_STATE_HOME="$HOME/demo/modes-verbs-state" WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel" "$root/.build/debug/WinMuxApp" > "$out/manager.log" 2>&1 &
sleep 15
"$W" config status > "$out/config-status.txt"
grep -q '"last-error" : null' "$out/config-status.txt"
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/initial-windows.txt"
window_id() { awk -F'|' -v app="$1" '$2 == app {print $1; exit}' "$out/initial-windows.txt"; }
for app in Zed Ghostty Safari Notes; do test -n "$(window_id "$app")"; done
snapshot() { bash "$HOME/modes/snapshot.sh" "$root" "$out" "$1"; }
select_app() {
  local target="$(window_id "$1")"
  for attempt in 1 2 3 4 5; do
    "$W" debug-lens-trace --json --last 1 > "$out/selection.json"
    local selected=$(jq -r '.[0].session.selectedId' "$out/selection.json")
    if [ "$selected" = "$target" ]; then return; fi
    "$W" lens step next
  done
  return 1
}
open_browse() { "$W" lens windows; "$W" mode browse; sleep 1; }
"$W" focus --window-id "$(window_id Ghostty)"
"$W" lens windows
sleep 1
snapshot inert-main
cliclick "t:printf 'INERT_PASS\\n' > '$out/inert.txt'" kp:return
sleep 1
test "$(cat "$out/inert.txt")" = INERT_PASS
snapshot inert-typed
"$W" lens close
open_browse
"$W" lens step next
"$W" lens step prev
"$W" lens step left
"$W" lens step right
"$W" lens step up
"$W" lens step down
"$W" lens sections next
snapshot grouping
"$W" lens presentation list
"$W" mode search
"$D" "$root" "$out" tap:z wait:1 snapshot:search-one
"$W" lens caret left
"$W" lens caret right
snapshot caret
"$W" mode browse
"$W" lens peek
sleep 1
snapshot peek
"$W" lens peek
"$W" lens close
open_browse
select_app Zed
"$D" "$root" "$out" down:cmd tap:2 up:cmd wait:3
"$W" lens close
"$W" workspace 1
sleep 2
snapshot selection-workspace-action
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/moved-windows.txt"
grep -q "$(window_id Zed)|Zed|2" "$out/moved-windows.txt"
open_browse
select_app Notes
"$W" lens summon
sleep 3
snapshot summoned
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/summoned-windows.txt"
grep -q "$(window_id Notes)|Notes|1" "$out/summoned-windows.txt"
"$W" move-node-to-workspace --window-id "$(window_id Zed)" 1
"$W" move-node-to-workspace --window-id "$(window_id Notes)" 2
sleep 3
"$W" workspace 2
sleep 2
snapshot restored-source
"$W" workspace 1
open_browse
select_app Zed
"$W" lens focus
sleep 2
snapshot focused
grep -qx main "$out/focused.mode.txt"
open_browse
if "$W" lens pane next > "$out/pane.stdout" 2> "$out/pane.stderr"; then exit 1; else test "$?" = 1; fi
snapshot no-panes
select_app Notes
"$W" lens mark
select_app Safari
"$W" lens mark
snapshot marks
"$W" lens run close
sleep 3
snapshot marked-close
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/remaining-windows.txt"
test "$(wc -l < "$out/remaining-windows.txt" | tr -d ' ')" = 2
"$W" lens close
open_browse
"$W" lens close-window
sleep 3
snapshot selected-close
"$W" lens close
snapshot closed-main
pkill -x WinMuxApp || true
sleep 3
