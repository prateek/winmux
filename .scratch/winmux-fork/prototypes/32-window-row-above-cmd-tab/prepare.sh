#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
zsh "$HOME/desk/stage-rich.sh"
cp "$HOME/row-prototype/system-desk.ncl" "$HOME/.config/winmux/winmux.ncl"
"$HOME/winmux/.build/debug/winmux" reload-config
sleep 3
"$HOME/winmux/.build/debug/winmux" doctor
killall UserNotificationCenter 2>/dev/null || true
mkdir -p "$HOME/takes/row"
swiftc "$HOME/row-prototype/dock-probe.swift" -o "$HOME/row-prototype/dock-probe"
sw_vers > "$HOME/takes/row/sw-vers.txt"
cliclick m:1870,1040
(sleep 0.8; screencapture -x "$HOME/takes/row/cliclick-system-switcher.png"; "$HOME/row-prototype/dock-probe" > "$HOME/takes/row/cliclick-dock-tree.txt") &
capture=$!
cliclick kd:cmd kp:tab w:1500 ku:cmd
wait "$capture"
