#!/bin/zsh
export TART_HOME=${TART_HOME:?Set TART_HOME before invoking the probe}
export PATH=/opt/homebrew/bin:$PATH
set -eu
root=${1:?source directory}
out=${2:?capture directory}
W=$root/.build/debug/winmux
mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 1
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
(nohup "$root/.build/debug/WinMuxApp" > "$out/start.log" 2>&1 &)
sleep 8
id() { $W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' -v a="$1" '$2==a {print $1; exit}'; }
normalize() {
    $W workspace 2 >/dev/null; $W workspace 1 >/dev/null
    for app in Notes Safari Ghostty Zed; do $W focus --window-id $(id "$app") >/dev/null; sleep .3; done
}
notes=$(id Notes)
normalize
for query in saf notes 'len saf' ''; do
    print -r -- "Search: $query" >> "$out/ranking.txt"
    $W list-windows --lens recent --search "$query" --format '%{window-id}|%{app-name}|%{window-title}' >> "$out/ranking.txt"
done
cliclick m:1260,690
$W lens recent --presentation grid --search ''
(cliclick w:1500 m:295,385 w:2000 c:967,385 w:1000 > "$out/grid-pointer.txt") &
sleep 2.4
screencapture -x "$out/grid-before-click.png"
$W debug-lens-trace --last 1 > "$out/grid-before-click.txt"
wait
$W debug-lens-trace --last 1 > "$out/grid-after-click.txt"
actual=$($W list-windows --focused --format '%{window-id}')
print "grid picture click: expected=$notes actual=$actual" | tee -a "$out/results.txt"
[[ $actual == $notes ]]
normalize
cliclick m:1260,690
(cliclick kd:cmd kp:tab w:1500 m:434,360 w:2000 c:836,360 w:1000 ku:cmd > "$out/strip-pointer.txt") &
sleep 2.7
screencapture -x "$out/strip-before-click.png"
$W debug-lens-trace --last 1 > "$out/strip-before-click.txt"
wait
$W debug-lens-trace --last 1 > "$out/strip-after-click.txt"
actual=$($W list-windows --focused --format '%{window-id}')
print "strip picture click: expected=$notes actual=$actual" | tee -a "$out/results.txt"
[[ $actual == $notes ]]
$W list-windows --all > "$out/windows.txt"
pkill -x WinMuxApp || true
