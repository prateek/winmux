#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
root="$HOME/winmux"
W="$root/.build/debug/winmux"
D="$HOME/modes/drive"
out="$HOME/takes/modes/pass2-extra"
mkdir -p "$out"
export WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel"
for invalid in missing recursive; do
    if "$W" config check "$HOME/modes/invalid-latch-$invalid.ncl" > "$out/invalid-$invalid.stdout" 2> "$out/invalid-$invalid.stderr"; then
        exit 1
    else
        test "$?" = 2
    fi
    grep -q latch-to "$out/invalid-$invalid.stderr"
done
cp "$HOME/modes/advanced.ncl" "$HOME/demo/modes-advanced-config/winmux/winmux.ncl"
"$W" config check "$HOME/demo/modes-advanced-config/winmux/winmux.ncl" > "$out/config-check.txt" 2>&1
pkill -x WinMuxApp || true
sleep 3
nohup env XDG_CONFIG_HOME="$HOME/demo/modes-advanced-config" XDG_STATE_HOME="$HOME/demo/modes-pass2-state" WINMUX_NICKEL_HELPER="$root/nickel-helper/target/release/winmux-nickel" "$root/.build/debug/WinMuxApp" > "$out/manager.log" 2>&1 &
sleep 15
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/initial-windows.txt"
ghostty=$(awk -F'|' '$2 == "Ghostty" { print $1; exit }' "$out/initial-windows.txt")
test -n "$ghostty"
"$W" focus --window-id "$ghostty"
sleep 2
"$D" "$root" "$out" down:cmd tap:tab wait:1 snapshot:held-before-escape tap:escape up:cmd wait:1 snapshot:held-escape
lsappinfo info -only name "$(lsappinfo front)" > "$out/held-escape.front.txt"
grep -q Ghostty "$out/held-escape.front.txt"
cliclick "t:printf 'ESCAPE_TYPING_OK\\n' > '$out/escape-typing.txt'" kp:return w:1000
test "$(cat "$out/escape-typing.txt")" = ESCAPE_TYPING_OK
bash "$HOME/modes/snapshot.sh" "$root" "$out" escape-typing

"$D" "$root" "$out" down:cmd tap:tab wait:1 tap:a wait:1 snapshot:latched-browse up:cmd wait:1
grep -qx browse "$out/latched-browse.mode.txt"
"$D" "$root" "$out" down:cmd tap:tab wait:1 snapshot:global-reentry up:cmd wait:1 snapshot:global-release
grep -qx cmd-tab "$out/global-reentry.mode.txt"
grep -qx main "$out/global-release.mode.txt"

"$W" focus --window-id "$ghostty"
sleep 2
cliclick 't:printf WRONG'
"$D" "$root" "$out" down:ctrl tap:u up:ctrl wait:0.3
cliclick "t:printf 'PASS2_REACHED_GHOSTTY\\n' > '$out/pass.txt'" kp:return w:1000
test "$(cat "$out/pass.txt")" = PASS2_REACHED_GHOSTTY
bash "$HOME/modes/snapshot.sh" "$root" "$out" app-pass

"$W" lens windows
"$W" mode search
sleep 1
"$D" "$root" "$out" tap:escape tap:j wait:1 snapshot:fast-escape-j
grep -qx browse "$out/fast-escape-j.mode.txt"
"$W" lens close
"$W" mode sequence
"$D" "$root" "$out" tap:g tap:t wait:1 snapshot:fast-sequence
grep -qx sequence "$out/fast-sequence.mode.txt"
"$W" lens close
"$W" mode main
"$W" lens --filter true --search z
"$W" mode search
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-z
"$W" lens --filter true --search Notes
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-notes
jq -e '.[0].session.active and .[0].session.search == "Notes"' "$out/ad-hoc-notes.trace.json"
"$W" lens --filter true --search Notes
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-toggled
grep -qx main "$out/ad-hoc-toggled.mode.txt"
"$W" lens --filter true
"$W" mode search
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-recalled
"$W" lens --filter true --search ''
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-empty
jq -e '.[0].session.active and .[0].session.search == ""' "$out/ad-hoc-empty.trace.json"
"$W" lens --filter true --search ''
sleep 1
bash "$HOME/modes/snapshot.sh" "$root" "$out" ad-hoc-empty-toggled
grep -qx main "$out/ad-hoc-empty-toggled.mode.txt"
"$W" mode sequence-global
"$D" "$root" "$out" tap:g tap:t wait:1 snapshot:global-sequence-complete
grep -qx main "$out/global-sequence-complete.mode.txt"
"$W" mode keypad-global
"$D" "$root" "$out" tap:keypad-enter wait:1 snapshot:keypad-enter-global
grep -qx main "$out/keypad-enter-global.mode.txt"
pkill -x WinMuxApp || true
sleep 3
