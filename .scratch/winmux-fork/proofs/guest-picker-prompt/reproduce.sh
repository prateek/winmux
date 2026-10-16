#!/bin/bash
set -u
out=$HOME/takes/repro
mkdir -p "$out"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/before.plist.txt"
/usr/bin/log stream --style compact --level debug --predicate 'process == "replayd" OR process == "tccd"' > "$out/decisions.log" 2>&1 &
echo $! > "$out/log.pid"
~/probe/watch "$out" > "$out/watch.log" 2>&1 &
echo $! > "$out/watch.pid"
for i in $(seq 1 300); do
 echo "$i" > "$out/count"
 if [ $((i % 10)) -eq 0 ]; then
   screencapture -x -v -V 1 "$out/video-$i.mov" >> "$out/captures.log" 2>&1
 else
   screencapture -x "$out/still.png" >> "$out/captures.log" 2>&1
 fi
 echo "$(date -u +%FT%TZ) capture=$i status=$?" >> "$out/captures.log"
 if [ $((i % 25)) -eq 0 ]; then plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/after-$i.plist.txt"; fi
done
~/probe/trace-recorder "$out/trace.mov" 3 > "$out/trace.log" 2>&1
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/after.plist.txt"
echo DONE >> "$out/captures.log"
