#!/bin/zsh
set -eu
W=$HOME/${WINMUX_CHECKOUT:-winmux}/.build/debug/winmux
presentation=${1:?strip or list}
title=${2:?window title}
out=$HOME/takes/close35/${3:?evidence prefix}
mkdir -p "$out"
windows() { $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}'; }
id() { windows | awk -F'|' -v title="$1" '$3==title {print $1; exit}'; }
target=$(id "$title")
zed=$(windows | awk -F'|' '$2=="Zed" {print $1; exit}')
[[ -n "$target" && -n "$zed" ]]
windows > "$out/windows-before.txt"
$W focus --window-id "$target"
sleep 0.3
$W focus --window-id "$zed"
sleep 0.3
/opt/homebrew/bin/cliclick m:1240,714
trigger=(down:cmd tap:tab wait:5 tap:w wait:7 up:cmd)
~/desk/keys 0 "$out/keys.json" $trigger &
driver=$!
sleep 1
if [[ $presentation == list ]]; then $W lens --presentation list; fi
sleep 1
$W debug-lens-trace --last 1 > "$out/trace-before.txt"
$W debug-lens-trace --last 1 --json > "$out/trace-before.json"
screencapture -x "$out/before.png"
sleep 4
$W debug-lens-trace --last 1 > "$out/trace-after.txt"
$W debug-lens-trace --last 1 --json > "$out/trace-after.json"
screencapture -x "$out/after.png"
windows > "$out/windows-after.txt"
wait $driver
if $W debug-lens-trace --last 1 --json | python3 -c 'import json,sys; sys.exit(not json.load(sys.stdin)[0]["session"]["active"])'; then
    $W lens recent
fi
$W debug-lens-trace --last 1 > "$out/trace-ended.txt"
windows > "$out/windows-ended.txt"
grep 'Session:' "$out/trace-before.txt" "$out/trace-after.txt"
echo "target=$target title=$title"
