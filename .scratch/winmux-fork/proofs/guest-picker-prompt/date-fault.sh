#!/bin/bash
set -eu
out=$HOME/takes/date-fault
mkdir -p "$out"
approvals="$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"
~/vm/preflight > "$out/healthy.txt"
cp "$approvals" "$out/original.plist"
killall -KILL replayd 2>/dev/null || true
sleep 1
python3 ~/probe/alter-approval.py used
plutil -p "$approvals" > "$out/before.plist.txt"
if ~/vm/preflight > "$out/stale.txt"; then result=0; else result=$?; fi
echo "exit=$result" >> "$out/stale.txt"
[ "$result" -eq 1 ]
echo 0 > "$out/count"
nohup ~/probe/watch "$out" > "$out/watch.log" 2>&1 < /dev/null &
echo $! > "$out/watch.pid"
nohup /usr/bin/log stream --style compact --level info --predicate 'process == "replayd" OR process == "tccd"' > "$out/decisions.log" 2>&1 < /dev/null &
echo $! > "$out/log.pid"
sleep 4
date -u +%FT%TZ > "$out/trigger.txt"
echo 1 > "$out/count"
screencapture -x "$out/trigger.png"
sleep 12
python3 - "$out/watch.log" <<'PY'
import sys
from pathlib import Path
lines=[line for line in Path(sys.argv[1]).read_text().splitlines() if 'UserNotificationCenter | ' in line]
assert lines, 'the corrected watcher did not detect the controlled prompt'
print(lines[0])
PY
plutil -p "$approvals" > "$out/after.plist.txt"
screencapture -x "$out/final.png"
cat "$out/healthy.txt" "$out/stale.txt" "$out/trigger.txt"
