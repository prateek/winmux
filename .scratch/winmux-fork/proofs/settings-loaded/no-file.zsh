#!/bin/zsh
set -eu
export TART_HOME=${TART_HOME:?}
tree=${1:?source tree}
binary=${2:?app executable}
name=${3:?take name}
export XDG_CONFIG_HOME=$HOME/demo/settings-no-file-$name
export XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel
file=$XDG_CONFIG_HOME/winmux/winmux.ncl
take=$HOME/takes/settings-loaded/no-file-$name
ui=$HOME/demo/settings-ui
[[ ! -e "$file" ]]
mkdir -p "$take"
pkill -x WinMuxApp || true
sleep 3
nohup "$binary" > "$take/app.log" 2>&1 &
sleep 20
p=$(pgrep -x WinMuxApp)
[[ ! -e "$file" ]]
"$ui" "$p" press 'Settings…'
sleep 2
"$ui" "$p" dump > "$take/before-open.ax"
screencapture -x "$take/before-open.png"
"$tree/.build/debug/winmux" config status > "$take/status.json"
if ! "$ui" "$p" press 'Open Config'; then "$ui" "$p" press 'Open config'; fi
sleep 2
[[ -f "$file" ]]
screencapture -x "$take/open-config.png"
for agent in $(pgrep -x CoreServicesUIAgent); do "$ui" "$agent" press Cancel || true; done
cp "$file" "$take/starter.ncl"
"$tree/.build/debug/winmux" config check "$file" > "$take/check.txt" 2>&1
shasum "$file" > "$take/starter.sha"
print 'PASS: startup writes no file; Open Config creates a valid starter'
