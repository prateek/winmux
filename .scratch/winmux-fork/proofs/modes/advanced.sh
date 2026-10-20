#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
root="$HOME/winmux"
W="$root/.build/debug/winmux"
D="$HOME/modes/drive"
out="$HOME/takes/modes/${1:-advanced-final}"
config="$HOME/demo/modes-advanced-config"
mkdir -p "$config/winmux" "$HOME/demo/modes-advanced-state" "$out"
cp "$HOME/modes/advanced.ncl" "$config/winmux/winmux.ncl"
export WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel"
"$W" config check "$config/winmux/winmux.ncl" > "$out/config-check.txt" 2>&1
pkill -x WinMuxApp || true
sleep 3
nohup env XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$HOME/demo/modes-advanced-state" WINMUX_NICKEL_HELPER="$WINMUX_NICKEL_HELPER" "$root/.build/debug/WinMuxApp" > "$out/manager.log" 2>&1 &
sleep 15
"$W" config status > "$out/config-status.txt"
grep -q 'modes-advanced-config' "$out/config-status.txt"
"$W" list-modes > "$out/modes.txt"
grep -q sequence "$out/modes.txt"
grep -q counting "$out/modes.txt"
assert_mode() { grep -qx "$2" "$out/$1.mode.txt"; }
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/initial-windows.txt"
window_id() { awk -F'|' -v app="$1" '$2 == app {print $1; exit}' "$out/initial-windows.txt"; }
for app in Zed Ghostty Safari Notes; do test -n "$(window_id "$app")"; done
"$W" focus --window-id "$(window_id Zed)"
"$W" move left || true
sleep 1
"$D" "$root" "$out" down:alt down:shift tap:semicolon up:shift up:alt wait:1 snapshot:once-enter \
  tap:l wait:1 snapshot:once-return
assert_mode once-enter window-once
assert_mode once-return main
"$W" mode sequence
sleep 1
"$D" "$root" "$out" snapshot:sequence-open tap:g wait:1 snapshot:sequence-pending \
  tap:l wait:1 snapshot:sequence-cancelled tap:g tap:t wait:1 snapshot:sequence-complete \
  tap:g tap:escape wait:1 snapshot:sequence-escape-pending \
  tap:escape wait:1 snapshot:sequence-closed
assert_mode sequence-pending sequence
assert_mode sequence-cancelled sequence
assert_mode sequence-complete sequence
assert_mode sequence-escape-pending sequence
assert_mode sequence-closed main
"$W" move-node-to-workspace --window-id "$(window_id Notes)" 1
sleep 3
"$W" workspace 2
sleep 2
bash "$HOME/modes/snapshot.sh" "$root" "$out" notes-left-workspace-2
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/notes-move-windows.txt"
"$W" focus --window-id "$(window_id Zed)"
"$W" move left || true
"$W" focus --window-id "$(window_id Notes)"
"$W" move right || true
"$W" focus --window-id "$(window_id Zed)"
"$W" mode counting
sleep 2
"$D" "$root" "$out" snapshot:count-before tap:2 wait:1 snapshot:count-prefix tap:l wait:2 snapshot:count-after \
  wait:1
grep -q '|Notes|' "$out/count-after.focus.txt"
"$W" lens close
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" count-closed
assert_mode count-closed main
"$W" move-node-to-workspace --window-id "$(window_id Notes)" 2
sleep 3
"$W" workspace 1
sleep 2
bash "$HOME/modes/snapshot.sh" "$root" "$out" notes-left-workspace-1
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/notes-return-windows.txt"
for letter in w o f s r a; do
  "$W" mode window
  "$D" "$root" "$out" "tap:$letter" wait:2 "snapshot:opener-$letter" tap:escape wait:1
  "$W" lens close 2>/dev/null || true
  "$W" mode main
done
"$W" focus --window-id "$(window_id Zed)"
sleep 1
"$D" "$root" "$out" down:ctrl tap:u up:ctrl wait:1 snapshot:app-bound
grep -q '|Ghostty|' "$out/app-bound.focus.txt"
"$W" focus --window-id "$(window_id Ghostty)"
sleep 2
cliclick 't:printf WRONG'
"$D" "$root" "$out" down:ctrl tap:u up:ctrl wait:0.3
line="printf 'PASS_REACHED_GHOSTTY\\n' > '$out/pass.txt'"
cliclick "t:$line" kp:return
sleep 2
test "$(cat "$out/pass.txt")" = PASS_REACHED_GHOSTTY
bash "$HOME/modes/snapshot.sh" "$root" "$out" app-pass
"$D" "$root" "$out" down:cmd tap:backtick wait:1 snapshot:backtick-open up:cmd wait:1 snapshot:backtick-release
assert_mode backtick-open cmd-backtick
assert_mode backtick-release main
"$W" focus --window-id "$(window_id Zed)"
sleep 1
"$D" "$root" "$out" down:cmd tap:tab up:cmd wait:2 snapshot:quick-tap
assert_mode quick-tap main
"$W" focus --window-id "$(window_id Zed)"
sleep 1
"$D" "$root" "$out" down:cmd tap:tab wait:1 snapshot:foreign-before \
  down:ctrl tap:h up:ctrl wait:1 snapshot:foreign-after up:cmd wait:1 snapshot:foreign-release
assert_mode foreign-before cmd-tab
assert_mode foreign-after main
assert_mode foreign-release main
"$W" mode cmd-tab > "$out/cli-held.stdout" 2> "$out/cli-held.stderr"
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" cli-held-latched
assert_mode cli-held-latched cmd-tab
grep -qi latched "$out/cli-held.stderr"
"$W" lens close
"$W" focus --window-id "$(window_id Ghostty)"
sleep 1
line="cat '$HOME/takes/modes/head-steady/cmd-tab-first.mode.txt' '$HOME/takes/modes/head-steady/search-typed.mode.txt' '$HOME/takes/modes/head-steady/search-browse.mode.txt' '$HOME/takes/modes/head-steady/search-closed.mode.txt' '$out/cli-held.stderr'"
cliclick "t:$line" kp:return
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" cli-readbacks
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/final-windows.txt"
pkill -x WinMuxApp || true
sleep 3
