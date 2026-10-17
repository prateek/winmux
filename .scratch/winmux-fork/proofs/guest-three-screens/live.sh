#!/bin/bash
# Run unchanged before desk staging on the old image and its replacement.
set -euo pipefail
prefix=${1:?usage: live.sh base-or-new}
mkdir -p ~/scratch-136 ~/takes
printf 'Fresh guest scratch note\n' > ~/scratch-136/note.txt
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Zed.app/Contents/Info.plist
/Applications/Ghostty.app/Contents/MacOS/ghostty --version
open -a Zed ~/scratch-136/note.txt
sleep 12
screencapture -x ~/takes/"$prefix-zed.png"
pkill -x zed || true
open -a Ghostty
sleep 4
osascript -e 'tell application "System Events" to keystroke "sleep 600"' \
  -e 'tell application "System Events" to key code 36'
sleep 2
pgrep -fl '^sleep 600$'
osascript -e 'tell application "System Events" to keystroke "q" using command down'
sleep 3
screencapture -x ~/takes/"$prefix-ghostty.png"
if pgrep -x ghostty; then echo 'Ghostty still running'; else echo 'Ghostty exited'; fi
pkill -x ghostty || true
pkill -f '^sleep 600$' || true
