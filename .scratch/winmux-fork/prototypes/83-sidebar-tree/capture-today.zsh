#!/bin/zsh
set -e
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/sidebar-tree
mkdir -p "$out/img"
swiftc "$HOME/sidebar-tree/icons.swift" -o "$HOME/sidebar-tree/icons"
"$HOME/sidebar-tree/icons" "$out/img"
for n in 1 2 3 4; do
  $W workspace "$n" >/dev/null
  sleep 3
  cliclick m:1870,1072
  sleep 1
  screencapture -x "$out/img/today-$n-collapsed.png"
  cliclick m:1,400
  sleep 1
  screencapture -x "$out/img/today-$n-expanded.png"
done
cliclick m:1870,1072
$W workspace 1 >/dev/null
sleep 2
$W list-workspaces --focused > "$out/raw/end-workspace.txt"
$W list-windows --focused > "$out/raw/end-focus.txt"
$W list-windows --all > "$out/raw/end-windows.txt"
pkill -x WinMuxApp || true
