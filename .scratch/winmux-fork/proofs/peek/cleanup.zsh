#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
$W debug-lens-trace --last 1 > ~/captures/final-closed.trace.txt
$W debug-lens-trace --last 1 --json > ~/captures/final-closed.trace.json
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > ~/captures/final-desk.txt
$W list-windows --focused > ~/captures/final-focus.txt
$W list-workspaces --focused > ~/captures/final-workspace.txt
for app in WinMuxApp Zed zed Ghostty ghostty Safari Notes; do pkill -TERM -x "$app" || true; done
guest_server_pid=$(/usr/sbin/lsof -tiTCP:8765 -sTCP:LISTEN || true)
if [[ -n "$guest_server_pid" ]]; then kill -TERM "$guest_server_pid"; fi
sleep 2
for app in WinMuxApp Zed zed Ghostty ghostty Safari Notes; do
  if pgrep -x "$app"; then print -u2 "Owned app still running: $app"; exit 1; fi
done
screencapture -x ~/captures/cleanup.png
print 'Debug build and owned desk apps stopped; docs server stopped' > ~/captures/cleanup.txt
