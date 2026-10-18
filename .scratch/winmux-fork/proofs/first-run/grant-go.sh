#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
out="$HOME/takes/first-run"
screencapture -x -v -V 55 "$out/grant-go.mov" > "$out/grant-go.recorder.txt" 2>&1 &
recorder=$!
python3 "$HOME/first-run/socket-routing.py" > "$out/socket-waiting-go.txt"
set +e
"$W" subscribe --all > "$out/subscribe-waiting-go.txt" 2>&1
echo "exit=$?" >> "$out/subscribe-waiting-go.txt"
set -e
cliclick kd:cmd kp:tab w:500 ku:cmd
screencapture -x "$out/hotkeys-before-go.png"
"$HOME/demo/frames" > "$out/hotkeys-before-go.frames.json"
"$HOME/demo/ui" com.zimengxiong.winmux.debug 'Start WinMux' > "$out/start-action.txt"
bash "$HOME/first-run/sample-step.sh" after-go
"$W" doctor > "$out/after-go.doctor.txt"
cliclick kd:cmd kp:tab w:1000
screencapture -x "$out/hotkeys-after-go.png"
cliclick ku:cmd
sleep 4
"$W" debug-lens-trace --last 1 > "$out/after-go.lens-trace.txt"
"$W" list-windows --all --format '%{app-name}|%{window-title}|%{workspace}' > "$out/after-go.windows.txt"
wait "$recorder"
