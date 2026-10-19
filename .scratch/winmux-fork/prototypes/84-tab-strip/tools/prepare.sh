#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
# Loopback URLs keep home paths out of captures.
open -a 'Google Chrome'
for suffix in notes layout shortcuts; do
  "$HOME/tab-strip-tools/keys" 0 /tmp/address.json down:cmd tap:l up:cmd
  cliclick t:"http://localhost:8765/desk.html#$suffix" kp:return w:500
  cliclick kd:ctrl kp:tab ku:ctrl
done
open -a Ghostty
sleep 1
for tab in 1 2 3; do
  if [ "$tab" != 1 ]; then "$HOME/tab-strip-tools/keys" 0 /tmp/tabs.json down:cmd tap:t up:cmd; fi
  cliclick t:"export PS1='› '; printf '\033]0;Strip checks\007'; clear; printf 'WINMUX / STRIP CHECKS\n\n  1741 Swift tests passed\n    92 helper tests passed\n   171 script tests passed\n\nOne group. Three apps.\n'" kp:return w:500
done
sleep 12
"$HOME/winmux/.build/debug/winmux" list-windows --all --json > "$HOME/takes/tab-strip/ready-windows.json"
screencapture -x "$HOME/takes/tab-strip/ready.png"
