#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
tree="$HOME/${1:-winmux}"
proof="$HOME/chrome-proof"
pkill -x WinMuxApp || true
sleep 3
pkill -x stage || true
sleep 2
mkdir -p "$HOME/demo/chrome-config/winmux" "$HOME/demo/chrome-state" "$HOME/takes/chrome-drops" "$HOME/demo"
cp "$proof/winmux.ncl" "$HOME/demo/chrome-config/winmux/winmux.ncl"
rm -f "$HOME/demo/chrome-state/winmux/workspace-sidebar.json"
swiftc "$HOME/winmux/.claude/skills/demo/stage.swift" -o "$HOME/demo/stage"
swiftc "$HOME/winmux/.scratch/winmux-fork/proofs/sidebar-tree/ui.swift" -o "$HOME/demo/ui"
swiftc "$HOME/winmux/.scratch/winmux-fork/proofs/sidebar-tree/scroll.swift" -o "$HOME/demo/scroll"
nohup env XDG_CONFIG_HOME="$HOME/demo/chrome-config" XDG_STATE_HOME="$HOME/demo/chrome-state" WINMUX_NICKEL_HELPER="$tree/nickel-helper/target/release/winmux-nickel" "$tree/.build/debug/WinMuxApp" > "$HOME/demo/chrome-app.log" 2>&1 < /dev/null &
sleep 15
nohup "$HOME/demo/stage" Red Blue Green Yellow Violet Orange Teal Pink Grey White Brown Black Amber Cyan Rose > "$HOME/demo/stage.log" 2>&1 < /dev/null &
sleep 20
"$tree/.build/debug/winmux" list-windows --all --format '%{window-id}|%{window-title}|%{workspace}'
python3 "$proof/live.py" stage "${2:-feature}"
