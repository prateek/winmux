#!/bin/zsh
set -eu
W=$HOME/${1:?checkout directory}/.build/debug/winmux
out=$HOME/takes/close35/${2:?evidence prefix}
mkdir -p "$out"
windows() { $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}'; }
id() { windows | awk -F'|' -v title="$1" '$3==title {print $1; exit}'; }
windows > "$out/ordinary-before.txt"
ordinary=$(id 'Close me')
[[ -n "$ordinary" ]]
$W focus --window-id "$ordinary"
$W close > "$out/ordinary-stdout.txt" 2> "$out/ordinary-stderr.txt"
echo "ordinary close: exit=$?" | tee "$out/results.txt"
windows > "$out/ordinary-after.txt"
! windows | awk -F'|' '$3=="Close me" {found=1} END {exit !found}'
[[ ! -s "$out/ordinary-stderr.txt" ]]
screencapture -x "$out/ordinary-after.png"
pkill -x CloseFixture
sleep 1
nohup ~/close35-fixture/CloseFixture --ordinary > /tmp/fixture.log 2>&1 &
sleep 2
ordinary=$(id 'Close me')
[[ -n "$ordinary" ]]
$W close --quit-if-last-window --window-id "$ordinary" > "$out/quit-stdout.txt" 2> "$out/quit-stderr.txt"
echo "quit-if-last-window: exit=$?" | tee -a "$out/results.txt"
sleep 1
! pgrep -x CloseFixture >/dev/null
windows > "$out/quit-after.txt"
[[ ! -s "$out/quit-stderr.txt" ]]
nohup ~/close35-fixture/CloseFixture > /tmp/fixture.log 2>&1 &
sleep 2
windows > "$out/restored.txt"
