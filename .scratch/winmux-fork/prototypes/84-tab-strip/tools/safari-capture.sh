#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
out="$HOME/takes/tab-strip"
page="file://$HOME/tab-strip/index.html"
swiftc "$HOME/tab-strip-tools/read-page.swift" -o "$HOME/tab-strip-tools/read-page"
open -a Safari "$page?work"
sleep 5
osascript <<'EOF'
tell application "System Events" to tell process "Safari"
 set frontmost to true
 set position of front window to {0, 30}
 set size of front window to {1920, 1050}
end tell
EOF
navigate() {
 "$HOME/tab-strip-tools/keys" 0 /tmp/safari-address.json down:cmd tap:l up:cmd
 cliclick t:"$page?$1" kp:return
 sleep 1
 cliclick c:1750,170 m:1860,1072
}
for app in chrome code ghostty; do
 for look in today thin held sidebar; do
  for grip in gone clear; do
   navigate "work&app=$app&look=$look&grip=$grip"
   screencapture -x -R0,120,1920,960 "$out/safari-$app-$look-$grip.png"
   "$HOME/tab-strip-tools/read-page" > "$out/safari-$app-$look-$grip.txt"
  done
 done
done
navigate 'work&look=held&app=chrome&grip=clear'
"$HOME/tab-strip-tools/keys" 0 "$out/safari-held.events.json" down:alt wait:1.0 up:alt &
keypid=$!
sleep .7
screencapture -x -R0,120,1920,960 "$out/safari-held-midhold.png"
wait "$keypid"
sleep 1
screencapture -x -R0,120,1920,960 "$out/safari-held-released.png"
"$HOME/tab-strip-tools/read-page" > "$out/safari-held-released.txt"
navigate 'work&look=today&app=chrome&grip=clear'
cliclick c:342,315 m:500,400
sleep 1
screencapture -x -R0,120,1920,960 "$out/safari-click-app-hover-tab.png"
"$HOME/tab-strip-tools/read-page" > "$out/safari-click-app-hover-tab.txt"
cliclick m:1618,400
sleep 1
screencapture -x -R0,120,1920,960 "$out/safari-handle-hover.png"
navigate 'work&look=sidebar&app=chrome&grip=clear'
cliclick m:222,500
sleep 1
screencapture -x -R0,120,1920,960 "$out/safari-sidebar-expanded.png"
cliclick m:1800,170
sleep 1
screencapture -x -R0,120,1920,960 "$out/safari-sidebar-collapsed.png"
navigate 'selftest'
"$HOME/tab-strip-tools/read-page" > "$out/safari-selftest.txt"
