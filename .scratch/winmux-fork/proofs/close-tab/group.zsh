#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
desiredGhostty=${1:-4}
out=$HOME/takes/close-tab
mkdir -p "$out"
pkill -x WinMuxApp || true
sleep 3
cd ~/winmux
XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel nohup .build/debug/WinMuxApp > "$out/group-app.log" 2>&1 &
sleep 12
$W workspace 1
sleep 2
windows=$($W list-windows --all --format '%{window-id}|%{app-name}')
ghostty=$(print -r -- "$windows" | awk -F'|' '$2=="Ghostty" {print $1; exit}')
count=$(print -r -- "$windows" | awk -F'|' '$2=="Ghostty" {n++} END {print n+0}')
[[ -n "$ghostty" ]]
$W focus --window-id "$ghostty"
sleep 1
[[ -x ~/desk/keys ]] || swiftc ~/winmux/.claude/skills/demo/keys.swift -o ~/desk/keys
for ((i=count; i<desiredGhostty; i++)); do
    ~/desk/keys 0 "$out/new-window-$i-keys.json" down:cmd tap:n up:cmd wait:2
done
sleep 5
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/five-before.txt"
[[ $(awk -F'|' '$2=="Ghostty" {n++} END {print n+0}' "$out/five-before.txt") == $desiredGhostty ]]
$W layout tiles horizontal || true
$W layout tab-group
sleep 3
cliclick m:1240,714
sleep 1
screencapture -x "$out/active-only.png"
~/close-tab-tools/ui $(pgrep -x WinMuxApp) > "$out/five-ui.txt"
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/five-grouped.txt"
