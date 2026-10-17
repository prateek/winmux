#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
case_name=$1
method=${2:-event}
out=$HOME/quit-proof/$case_name
pid=$(cat "$out/pid")
case "$method" in
  event) "$HOME/quit-tools/quit" "$pid" > "$out/quit-event.txt" ;;
  signal) kill -TERM "$pid" ;;
  menu)
    cliclick c:1013,15 w:300
    screencapture -x "$out/menu-open.png"
    cliclick c:1093,203 m:1240,714
    ;;
esac
sleep 4
if kill -0 "$pid" 2>/dev/null; then echo 'WinMux did not exit' >&2; exit 1; fi
"$HOME/quit-tools/frames" > "$out/after.json"
screencapture -x "$out/after.png"
/usr/bin/log show --info --last 10m --style compact --predicate 'category == "quit-frames" AND process == "WinMuxApp"' |
  awk -v pid="$pid" 'index($0, "WinMuxApp[" pid ":")' > "$out/unified.log"
echo "Finished: $case_name ($method)"
