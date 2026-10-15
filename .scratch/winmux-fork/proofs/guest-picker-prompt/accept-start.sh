#!/bin/bash
set -eu
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/accept
mkdir -p "$out" ~/demo/config/winmux
# Close only the owned blank Safari windows left after switching desk sets.
for window in $("$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' | awk -F'|' '$2=="Safari" && ($3=="Untitled" || $3=="Start Page") {print $1}'); do
 "$W" close --window-id "$window"
done
"$W" list-windows --all --format '%{app-name}|%{window-title}|%{workspace}' > ~/takes/standing/checked-windows.txt
[ "$(wc -l < ~/takes/standing/checked-windows.txt | tr -d ' ')" -eq 4 ]
for app in Zed Ghostty Safari Notes; do
 [ "$(awk -F'|' -v app="$app" '$1==app {n++} END {print n+0}' ~/takes/standing/checked-windows.txt)" -eq 1 ]
done
swiftc -O ~/desk/check-desk.swift -o ~/desk/check-desk
ids=($("$W" list-windows --all --format '%{window-id}'))
for workspace in 1 2; do
 "$W" workspace "$workspace"
 sleep 1
 ~/desk/check-desk "${ids[@]}" >> ~/takes/standing/check.txt
 screencapture -x "$HOME/takes/standing/workspace-$workspace.png"
done
"$W" workspace 1
pkill -x WinMuxApp
sleep 3
cp ~/desk/winmux.ncl ~/demo/config/winmux/winmux.ncl
export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
nohup "$HOME/winmux/.build/debug/WinMuxApp" > "$out/winmux.log" 2>&1 < /dev/null &
echo $! > "$out/app.pid"
sleep 6
"$W" workspace 2
sleep 1
"$W" workspace 1
sleep 1
/opt/homebrew/bin/cliclick m:1240,714
"$W" list-workspaces --focused > "$out/start-workspace.txt"
"$W" list-windows --focused > "$out/start-focus.txt"
"$W" list-windows --all > "$out/start-windows.txt"
ps -p "$(cat "$out/app.pid")" -o pid=,etime=,lstart=,command= > "$out/process-start.txt"
kill "$(cat ~/takes/fresh/watch.pid)"
nohup ~/probe/watch "$out" > "$out/watch.log" 2>&1 < /dev/null &
echo $! > "$out/watch.pid"
nohup /usr/bin/log stream --style compact --level info --predicate '(process == "replayd" AND (eventMessage CONTAINS "SCAlert" OR eventMessage CONTAINS "privacy hint")) OR (process == "tccd" AND eventMessage CONTAINS "Handling access request to kTCCServiceScreenCapture")' > "$out/decisions.log" 2>&1 < /dev/null &
echo $! > "$out/log.pid"
plutil -p "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" > "$out/start.plist.txt"
nohup bash ~/probe/lenses-v2.sh "$out" 120 > "$out/lenses-driver.log" 2>&1 < /dev/null &
nohup bash ~/probe/accept-captures.sh > "$out/captures-driver.log" 2>&1 < /dev/null &
date -u +%FT%TZ > "$out/started.txt"
cat "$out/started.txt" "$out/process-start.txt" "$out/start-windows.txt"
