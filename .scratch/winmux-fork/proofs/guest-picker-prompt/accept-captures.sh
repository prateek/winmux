#!/bin/bash
set -eu
out=$HOME/takes/accept
mkdir -p "$out"
echo $$ > "$out/captures.pid"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/before.plist.txt"
for i in $(seq 1 1000); do
 echo "$i" > "$out/count"
 date -u +%FT%TZ >> "$out/captures.log"
 if [ $((i % 10)) -eq 0 ]; then
   kind=video
   file="$out/video-$i.mov"
   screencapture -x -v -V 1 "$file" >> "$out/captures.log" 2>&1
 else
   kind=still
   file="$out/still-$i.png"
   screencapture -x "$file" >> "$out/captures.log" 2>&1
 fi
 [ -s "$file" ]
 echo "capture=$i kind=$kind status=0" >> "$out/captures.log"
done
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/after-1000.plist.txt"
screencapture -x "$out/final-captures.png"
date -u +%FT%TZ >> "$out/captures.log"
echo DONE >> "$out/captures.log"
