#!/bin/bash
set -eu
out=$HOME/takes/post-reboot
mkdir -p "$out"
nohup ~/probe/watch "$out" > "$out/watch.log" 2>&1 < /dev/null &
echo $! > "$out/watch.pid"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/before.plist.txt"
screencapture -x "$out/warmup.png"
sleep 3
screencapture -x -v -V 3 "$out/system.mov" > "$out/system.log" 2>&1
[ -s "$out/system.mov" ]
screencapture -x "$out/final-system.png"
~/probe/trace-recorder "$out/trace.mov" 3 > "$out/trace.log" 2>&1
[ -s "$out/trace.mov" ]
screencapture -x "$out/final-trace.png"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/after.plist.txt"
for movie in system trace; do
 /opt/homebrew/bin/ffprobe -v error -count_packets -show_entries 'format=duration:stream=codec_type,width,height,nb_read_packets' -of json "$out/$movie.mov" > "$out/$movie-media.json"
done
~/vm/preflight > "$out/preflight.txt"
cat "$out/preflight.txt" "$out/system-media.json" "$out/trace-media.json"
