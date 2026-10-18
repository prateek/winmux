#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
checkout=${1:?checkout directory}
label=${2:?capture label}
W=$HOME/$checkout/.build/debug/winmux
out=$HOME/takes/close-tab/$label
mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 3
cd "$HOME/$checkout"
XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/$checkout/nickel-helper/target/release/winmux-nickel nohup .build/debug/WinMuxApp > "$out/app.log" 2>&1 &
sleep 12
$W workspace 1
sleep 2
~/close-tab-tools/CloseFixture --ordinary > "$out/fixture.log" 2>&1 &
fixture=$!
sleep 5
id=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Close me" {print $1; exit}')
[[ -n "$id" ]]
$W focus --window-id "$id"
sleep 1
result=0
$W close --window-id "$id" > "$out/close.stdout" 2> "$out/close.stderr" || result=$?
sleep 3
remaining=$($W list-windows --all --format '%{window-title}' | grep -c '^Close me$' || true)
print "ordinary close: exit=$result remaining=$remaining" > "$out/result.txt"
[[ $result == 0 && $remaining == 0 ]]
kill "$fixture" 2>/dev/null || true
~/close-tab-tools/CloseFixture > "$out/fixture-refused.log" 2>&1 &
fixture=$!
sleep 5
id=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="No close button" {print $1; exit}')
[[ -n "$id" ]]
result=0
$W close --window-id "$id" > "$out/refused.stdout" 2> "$out/refused.stderr" || result=$?
sleep 2
remaining=$($W list-windows --all --format '%{window-title}' | grep -c '^No close button$' || true)
print "no-button close: exit=$result remaining=$remaining" >> "$out/result.txt"
cat "$out/refused.stderr" >> "$out/result.txt"
[[ $result == 1 && $remaining == 1 ]]
kill "$fixture" 2>/dev/null || true
pkill -x WinMuxApp || true
sleep 3
cat "$out/result.txt"
