#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
out="$HOME/takes/tab-strip"
pkill -x WinMuxApp || true
sleep 4
open -a Ghostty
osascript <<'EOF'
tell application "System Events" to tell process "Ghostty"
 set frontmost to true
 repeat with w in windows
  set position of w to {62, 42}
  set size of w to {1846, 1025}
 end repeat
end tell
EOF
cliclick m:1860,1072
sleep 3
screencapture -x "$out/native-ghostty.png"
osascript <<'EOF'
tell application "Finder"
 activate
 make new Finder window to POSIX file "/Applications"
 set bounds of front Finder window to {62, 42, 1908, 1067}
end tell
EOF
sleep 2
for i in 1 2; do
 "$HOME/tab-strip-tools/keys" 0 /tmp/finder-tabs.json down:cmd tap:t up:cmd
 sleep 1
 "$HOME/tab-strip-tools/keys" 0 /tmp/finder-go.json down:cmd down:shift tap:g up:shift up:cmd
 cliclick t:/Applications kp:return w:500
done
osascript <<'EOF'
tell application "System Events" to tell process "Finder"
 if exists menu item "Hide Sidebar" of menu "View" of menu bar 1 then
  click menu item "Hide Sidebar" of menu "View" of menu bar 1
 end if
end tell
EOF
cliclick m:1860,1072
sleep 3
screencapture -x "$out/native-finder.png"
"$HOME/tab-strip-tools/ui" Finder > "$out/native-finder-ui.txt"
"$HOME/tab-strip-tools/ui" Ghostty > "$out/native-ghostty-ui.txt"
