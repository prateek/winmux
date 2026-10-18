#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/close-tab
swiftc ~/winmux/.claude/skills/demo/trace-recorder.swift -o ~/close-tab-tools/trace-recorder
swiftc ~/close-tab-tools/mouse-events.swift -o ~/close-tab-tools/mouse-events
~/winmux/.build/debug/winmux list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/timed-three-before.txt"
cliclick m:495,60
sleep 1
rm -f "$out/timed-three.mov" "$out/timed-three-system.mov"
~/close-tab-tools/mouse-events "$out/timed-clicks.json" 12 > "$out/mouse-events.log" 2>&1 &
mouse=$!
~/close-tab-tools/trace-recorder "$out/timed-three.mov" 9 > "$out/trace-recorder.log" 2>&1 &
trace=$!
screencapture -x -k -v -V 9 "$out/timed-three-system.mov" > "$out/timed-recorder.log" 2>&1 &
system=$!
sleep 3
cliclick c:495,60 w:400 c:495,60 w:400 c:495,60 w:1000 m:1240,714
wait "$system"
wait "$trace"
wait "$mouse"
sleep 2
~/winmux/.build/debug/winmux list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/timed-three-after.txt"
