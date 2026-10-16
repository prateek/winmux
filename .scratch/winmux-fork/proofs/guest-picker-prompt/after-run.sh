#!/bin/bash
set -eu
out=$HOME/takes/accept
W=$HOME/winmux/.build/debug/winmux
export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
[ "$(tail -1 "$out/lenses.log")" = DONE ]
[ "$(tail -1 "$out/captures.log")" = DONE ]
"$W" debug-lens-trace --last 1 > "$out/end-trace.txt"
"$W" list-workspaces --focused > "$out/end-workspace.txt"
"$W" list-windows --focused > "$out/end-focus.txt"
"$W" list-windows --all > "$out/end-windows.txt"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/before-reboot.plist.txt"
screencapture -x "$out/final-before-cleanup.png"
pkill -x WinMuxApp
sleep 3
swiftc -O ~/probe/close-owned.swift -o ~/probe/close-owned
~/probe/close-owned > "$out/cleanup.txt"
sleep 3
for app in Zed zed Ghostty ghostty Safari Notes; do pkill -x "$app" || true; done
sleep 2
~/vm/preflight > "$out/clean-preflight.txt"
screencapture -x "$out/final-clean.png"
sync
cat "$out/end-workspace.txt" "$out/end-focus.txt" "$out/end-windows.txt" "$out/cleanup.txt" "$out/clean-preflight.txt"
