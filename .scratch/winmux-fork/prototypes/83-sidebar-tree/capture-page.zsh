#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/sidebar-tree/page
mkdir -p "$out"
swiftc "$HOME/sidebar-tree/read-page.swift" -o "$HOME/sidebar-tree/read-page"
swiftc "$HOME/sidebar-tree/drag.swift" -o "$HOME/sidebar-tree/drag"
capture() { screencapture -x "$out/$1.png"; "$HOME/sidebar-tree/read-page" > "$out/$1.txt"; }
navigate() {
  osascript -e 'tell application "System Events" to tell process "Safari" to set frontmost to true' \
    -e 'tell application "System Events" to keystroke "l" using command down'
  cliclick "t:file://$HOME/sidebar-tree/index.html?view=work&variant=$1" kp:return w:500
  sleep 2
}
for v in A B C; do
  navigate "$v"
  cliclick m:1750,180
  capture "$v-expanded"
  cliclick c:735,183 m:1750,180 w:700
  capture "$v-collapsed"
  cliclick m:238,300 w:700
  capture "$v-hover"
  cliclick c:735,183 m:1750,180 w:300
  cliclick c:329,342 w:300
  capture "$v-branch-collapsed"
  cliclick c:329,342 w:300
  "$HOME/sidebar-tree/drag" 420 365 254 490 &
  drag_pid=$!
  sleep 1.9
  screencapture -x "$out/$v-accepted-target.png"
  wait "$drag_pid"
  cliclick m:1750,180 w:500
  capture "$v-accepted"
  cliclick c:725,114 w:300
  "$HOME/sidebar-tree/drag" 420 365 420 318 &
  drag_pid=$!
  sleep 1.9
  screencapture -x "$out/$v-refused-target.png"
  wait "$drag_pid"
  cliclick m:1750,180 w:300
  capture "$v-refused"
  cliclick c:480,114 t:Safari w:500
  capture "$v-search-safari"
done
for term in Grievances qzxnomatch; do
  cliclick c:725,114 w:200 c:480,114 "t:$term" w:400
  capture "C-search-$term"
done
cliclick c:725,114 w:200
capture final
