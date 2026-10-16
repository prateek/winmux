#!/bin/bash
set -eu
mode=$1
out=$HOME/takes/control-$mode
mkdir -p "$out"
approvals="$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"
cp "$approvals" "$out/original.plist"
killall -KILL replayd 2>/dev/null || true
sleep 1
python3 ~/probe/alter-approval.py "$mode"
plutil -p "$approvals" > "$out/before.txt"
date -u +%FT%TZ > "$out/run.log"
screencapture -x -v -V 2 "$out/take.mov" >> "$out/run.log" 2>&1 &
echo $! > "$out/recorder.pid"
sleep 8
plutil -p "$approvals" > "$out/after.txt"
screencapture -x "$out/final.png"
date -u +%FT%TZ >> "$out/run.log"
