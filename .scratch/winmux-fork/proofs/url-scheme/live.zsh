#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
export PATH=/opt/homebrew/bin:$PATH
W="$HOME/winmux/.build/debug/winmux"
out="$HOME/takes/url"
original=$(pgrep -x WinMuxApp)
[[ $(print -r -- "$original" | wc -l | tr -d ' ') == 1 ]]
checkProcess() {
    local after=$(pgrep -x WinMuxApp)
    if [[ "$after" != "$original" ]]; then
        for pid in ${(f)after}; do [[ "$pid" == "$original" ]] || kill "$pid"; done
        print SECOND_INSTANCE
        lsappinfo list
        exit 1
    fi
}
sendURL() {
    open "$1"
    sleep 2
    checkProcess
}
shot() { screencapture -x "$out/$1.png" }
readWorkspace() { "$W" list-workspaces --focused }

# Keep two non-empty workspaces across manager restarts, then warm both.
windows=$("$W" list-windows --all --format '%{window-id}|%{app-name}')
for app in Safari Notes; do
    id=$(print -r -- "$windows" | awk -F'|' -v app="$app" '$2==app {print $1}')
    "$W" move-node-to-workspace --window-id "$id" 2
done
"$W" workspace 2
sleep 2
"$W" workspace 1
sleep 2
cliclick m:1240,714

"$W" workspace 2
sleep 2
readWorkspace > "$out/workspace-cli.txt"
shot workspace-cli
"$W" workspace 1
sleep 2
sendURL 'winmux://run/workspace/2'
readWorkspace > "$out/workspace-url.txt"
shot workspace-url
cmp "$out/workspace-cli.txt" "$out/workspace-url.txt"
"$W" workspace 1
sleep 2

"$W" lens overview
sleep 3
"$W" debug-lens-trace --json --last 1 > "$out/overview-cli.json"
shot overview-cli
cliclick kp:esc
sleep 2
"$W" debug-lens-trace --json --last 1 > "$out/overview-cli-closed.json"
sendURL 'winmux://run/lens/overview'
sleep 1
"$W" debug-lens-trace --json --last 1 > "$out/overview-url.json"
shot overview-url
cliclick kp:esc
sleep 2
"$W" debug-lens-trace --json --last 2 > "$out/overview-closed.json"
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/after-overview-windows.txt"
shot no-extra-window

"$W" mode window
sleep 2
"$W" list-modes --current > "$out/mode-cli.txt"
shot mode-cli
"$W" mode main
sleep 2
sendURL 'winmux://run/mode/window'
"$W" list-modes --current > "$out/mode-url.txt"
shot mode-url
cmp "$out/mode-cli.txt" "$out/mode-url.txt"
sendURL 'winmux://run/mode/main'
"$W" list-modes --current > "$out/mode-return.txt"

"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/refusals-before-windows.txt"
readWorkspace > "$out/refusals-before-workspace.txt"
index=0
for url in 'winmux://run/' 'winmux://nope/workspace/2' 'winmux://run/list-windows' 'winmux://run/workspace/--stdin' 'winmux://run/workspace/next/--stdin' 'winmux://run/exec-and-forget/echo%20forbidden' 'winmux://run/list-windows/--all'; do
    index=$((index+1))
    sendURL "$url"
    "$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/refusal-$index-windows.txt"
    readWorkspace > "$out/refusal-$index-workspace.txt"
    cmp "$out/refusals-before-windows.txt" "$out/refusal-$index-windows.txt"
    cmp "$out/refusals-before-workspace.txt" "$out/refusal-$index-workspace.txt"
    shot "refusal-$index"
done

config="$HOME/demo/url-config/winmux/winmux.ncl"
cp "$config" "$HOME/demo/url-config-original.ncl"
cp "$HOME/url-proof/off.ncl" "$config"
sleep 4
"$W" config status > "$out/setting-off-status.json"
sendURL 'winmux://run/workspace/2'
readWorkspace > "$out/setting-off-workspace.txt"
cmp "$out/refusals-before-workspace.txt" "$out/setting-off-workspace.txt"
shot setting-off
cp "$HOME/demo/url-config-original.ncl" "$config"
sleep 4
"$W" config status > "$out/setting-on-status.json"

open 'winmux://run/workspace/2'
open 'winmux://run/workspace/1'
sleep 4
checkProcess
readWorkspace > "$out/ordered-workspace.txt"
shot ordered

sendURL 'winmux://run/enable/on'
sendURL 'winmux://run/focus/--window-id/4294967295'
"$W" list-modes --current > "$out/after-failure-mode.txt"
shot failed-command

"$W" enable off
sleep 2
sendURL 'winmux://run/workspace/2'
sendURL 'winmux://run/enable/on'
sleep 3
readWorkspace > "$out/after-enable-workspace.txt"
shot reenabled

/usr/bin/log show --last 20m --info --predicate 'subsystem == "com.zimengxiong.winmux.debug" AND category == "url"' > "$out/url.log"
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/final-windows.txt"
checkProcess
print -r -- "$original" > "$out/final-pid.txt"
shot final-desk
print 'CLI/URL workspace and mode readbacks match; all refusal snapshots match.'
