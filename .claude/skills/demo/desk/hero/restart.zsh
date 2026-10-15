#!/bin/zsh
# A restart alone can renumber the sidebar; restage to restore 1 above 2.
set -eu
export PATH=/opt/homebrew/bin:$PATH
pkill -x WinMuxApp || true
sleep 2
~/desk/stage-desk.sh
W=$HOME/winmux/.build/debug/winmux
for app in Notes Safari Ghostty Zed; do
  id=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' -v a="$app" '$2==a {print $1; exit}')
  $W focus --window-id "$id"
  sleep .7
done
cliclick ku:fn m:1240,714
sleep 2
$W debug-lens-trace --last 1
